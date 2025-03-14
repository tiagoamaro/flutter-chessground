import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chessground/chessground.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart'
    hide Tuple2;
import 'package:dartchess/dartchess.dart' as dc;

import 'board_thumbnails.dart';
import 'draw_shapes.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chessground Demo',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blueGrey,
      ),
      home: const HomePage(title: 'Chessground Demo'),
    );
  }
}

enum Mode {
  botPlay,
  freePlay,
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  dc.Position<dc.Chess> position = dc.Chess.initial;
  Side orientation = Side.white;
  String fen = dc.kInitialBoardFEN;
  Move? lastMove;
  Move? premove;
  ValidMoves validMoves = IMap(const {});
  Side sideToMove = Side.white;
  PieceSet pieceSet = PieceSet.merida;
  BoardTheme boardTheme = BoardTheme.blue;
  bool immersiveMode = false;
  Mode playMode = Mode.botPlay;
  dc.Position<dc.Chess>? lastPos;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: playMode == Mode.botPlay
            ? const Text('Random Bot')
            : const Text('Free Play'),
      ),
      drawer: Drawer(
          child: ListView(
        children: [
          ListTile(
            title: const Text('Random Bot'),
            onTap: () {
              setState(() {
                playMode = Mode.botPlay;
              });
              if (position.turn == dc.Side.black) {
                _playBlackMove();
              }
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('Free Play'),
            onTap: () {
              setState(() {
                playMode = Mode.freePlay;
              });
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('Board Thumbnails'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BoardThumbnailsPage(),
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Draw Shapes'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DrawShapesPage(),
                ),
              );
            },
          ),
        ],
      )),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Board(
              size: screenWidth,
              settings: BoardSettings(
                pieceAssets: pieceSet.assets,
                colorScheme: boardTheme.colors,
                enableCoordinates: true,
              ),
              data: BoardData(
                interactableSide: playMode == Mode.botPlay
                    ? InteractableSide.white
                    : (position.turn == dc.Side.white
                        ? InteractableSide.white
                        : InteractableSide.black),
                validMoves: validMoves,
                orientation: orientation,
                fen: fen,
                lastMove: lastMove,
                sideToMove:
                    position.turn == dc.Side.white ? Side.white : Side.black,
                isCheck: position.isCheck,
                premove: premove,
              ),
              onMove: playMode == Mode.botPlay
                  ? _onUserMoveAgainstBot
                  : _onUserMoveFreePlay,
              onPremove: _onSetPremove,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ElevatedButton(
                  child:
                      Text("Immersive mode: ${immersiveMode ? 'ON' : 'OFF'}"),
                  onPressed: () {
                    setState(() {
                      immersiveMode = !immersiveMode;
                    });
                    if (immersiveMode) {
                      SystemChrome.setEnabledSystemUIMode(
                          SystemUiMode.immersiveSticky);
                    } else {
                      SystemChrome.setEnabledSystemUIMode(
                          SystemUiMode.edgeToEdge);
                    }
                  },
                ),
                ElevatedButton(
                  child: Text('Orientation: ${orientation.name}'),
                  onPressed: () {
                    setState(() {
                      orientation = orientation.opposite;
                    });
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    ElevatedButton(
                      child: Text('Piece set: ${pieceSet.label}'),
                      onPressed: () => _showChoicesPicker<PieceSet>(
                        context,
                        choices: PieceSet.values,
                        selectedItem: pieceSet,
                        labelBuilder: (t) => Text(t.label),
                        onSelectedItemChanged: (PieceSet? value) {
                          setState(() {
                            if (value != null) {
                              pieceSet = value;
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      child: Text('Board theme: ${boardTheme.label}'),
                      onPressed: () => _showChoicesPicker<BoardTheme>(
                        context,
                        choices: BoardTheme.values,
                        selectedItem: boardTheme,
                        labelBuilder: (t) => Text(t.label),
                        onSelectedItemChanged: (BoardTheme? value) {
                          setState(() {
                            if (value != null) {
                              boardTheme = value;
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                if (playMode == Mode.freePlay)
                  Center(
                      child: IconButton(
                          onPressed: lastPos != null
                              ? () => setState(() {
                                    position = lastPos!;
                                    fen = position.fen;
                                    validMoves =
                                        dc.algebraicLegalMoves(position);
                                    lastPos = null;
                                  })
                              : null,
                          icon: const Icon(Icons.chevron_left_sharp))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showChoicesPicker<T extends Enum>(
    BuildContext context, {
    required List<T> choices,
    required T selectedItem,
    required Widget Function(T choice) labelBuilder,
    required void Function(T choice) onSelectedItemChanged,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.only(top: 12),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: choices.map((value) {
              return RadioListTile<T>(
                title: labelBuilder(value),
                value: value,
                groupValue: selectedItem,
                onChanged: (value) {
                  if (value != null) onSelectedItemChanged(value);
                  Navigator.of(context).pop();
                },
              );
            }).toList(growable: false),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    validMoves = dc.algebraicLegalMoves(position);
    super.initState();
  }

  void _onSetPremove(Move? move) {
    setState(() {
      premove = move;
    });
  }

  void _onUserMoveFreePlay(Move move, {bool? isDrop, bool? isPremove}) {
    lastPos = position;
    final m = dc.Move.fromUci(move.uci)!;
    setState(() {
      position = position.playUnchecked(m);
      lastMove = move;
      fen = position.fen;
      validMoves = dc.algebraicLegalMoves(position);
    });
  }

  void _onUserMoveAgainstBot(Move move, {bool? isDrop, bool? isPremove}) async {
    lastPos = position;
    final m = dc.Move.fromUci(move.uci)!;
    setState(() {
      position = position.playUnchecked(m);
      lastMove = move;
      fen = position.fen;
      validMoves = IMap(const {});
    });
    await _playBlackMove();
  }

  Future<void> _playBlackMove() async {
    Future.delayed(const Duration(milliseconds: 100)).then((value) {
      setState(() {});
    });
    if (!position.isGameOver) {
      final random = Random();
      await Future.delayed(Duration(milliseconds: random.nextInt(5500) + 500));
      final allMoves = [
        for (final entry in position.legalMoves.entries)
          for (final dest in entry.value.squares)
            dc.NormalMove(from: entry.key, to: dest)
      ];
      if (allMoves.isNotEmpty) {
        final mv = (allMoves..shuffle()).first;
        setState(() {
          position = position.playUnchecked(mv);
          lastMove =
              Move(from: dc.toAlgebraic(mv.from), to: dc.toAlgebraic(mv.to));
          fen = position.fen;
          validMoves = dc.algebraicLegalMoves(position);
        });
        lastPos = position;
      }
    }
  }
}
