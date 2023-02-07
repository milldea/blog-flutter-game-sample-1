import 'dart:math';
import 'dart:ui' as ui;
import 'package:catch_the_star/star.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';

class GamePage extends StatefulWidget {
  const GamePage({Key? key, required this.endlessMode, required this.twinkleMode}) : super(key: key);
  final bool endlessMode;
  final bool twinkleMode;
  @override
  State<GamePage> createState() => _GamePage();
}

class _GamePage extends State<GamePage> {
  // 画面サイズを取得するためのグローバルキー
  final GlobalKey _targetKey = GlobalKey();

  // スコア表示のフォーマッタ
  final formatter = NumberFormat("#,###");

  // 長押しで終了にする秒数
  final int longPressFinishSeconds = 10;

  // 音を出すかどうか
  bool sounds = false;

  // 前回 frameCallback が呼ばれた時間
  int lastMilliseconds = 0;

  // 長押し開始時間
  int longPressStart = 0;

  // ゲームオーバーアニメーションを開始した時間
  int gameOverStart = 0;

  // ゲームレベル
  int level = 1;

  // スコア
  int score = 0;

  // チェイン
  int chain = 0;

  // スコア
  int highScore = 0;
  int maxChain = 0;

  // ハイスコア達成時の表示制御フラグ
  bool isHighScore = false;

  // frameCallback の呼び出された回数
  int count = 0;

  // 一度に画面内に表示できる最大の星の数
  int maxStar = 30;

  // ゲームオーバー時の画面の振動
  int vibrationX = 0;
  int vibrationY = 0;

  // 一定間隔で星が生成されると飽きるので、確率で表示させるための割合
  // この場合は 1/15
  int birthRate = 15;

  // 音源の再生
  AudioCache cache = AudioCache();
  // 音源のパス
  String starSoundPath = "sounds/star.mp3";
  String bombSoundPath = "sounds/bomb.mp3";
  String birthSoundPath = "sounds/birth.mp3";

  // 描画する画像
  ui.Image? starYellow;
  ui.Image? starRed;
  ui.Image? meteoriteRed;
  ui.Image? meteoriteBlue;

  // 生成された星を持たせる配列
  List<Star> stars = <Star>[];

  // ゲームオーバーになったかどうか
  bool isGameOver = false;

  // frameCallback のループ呼び出しを終了させるためのフラグ
  // 画面終了時にフラグを立てる
  bool endFlag = false;
  late SharedPreferences prefs;

  // 画面タップ位置を保持する座標
  double tapX = -1;
  double tapY = -1;

  // twinkle mode で星を表示させ続ける座標
  double twinkleX = -1;
  double twinkleY = -1;

  // 画面に表示する文字列
  String modeName = "Endless Mode";


  @override
  void dispose() {
    super.dispose();
    endFlag = true;
  }

  /// 画面描画が更新させた際に呼び出される callback
  ///
  void frameCallback(Duration duration){
    // 画面が dispose 済みなら終了
    if (endFlag) return;

    // 描画エリアのコンテナサイズを取得
    Size? containerSize = _targetKey.currentContext?.size;
    // サイズが未取得の場合は処理を終了
    if (containerSize == null) return;
    int containerWidth = containerSize.width.toInt();
    int containerHeight = containerSize.height.toInt();

    setState(() {
      // 経過時間を保存しておく
      if (lastMilliseconds == 0) {
        lastMilliseconds = duration.inMilliseconds;
      }
      // 距離計算用に、経過時間を計算しておく
      int diffTime = duration.inMilliseconds - lastMilliseconds;

      lastMilliseconds = duration.inMilliseconds;

      // エンドレスモードで、指定秒数以上長押ししていたら game over にする
      if (widget.endlessMode
          && lastMilliseconds - longPressStart > longPressFinishSeconds * 1000
          && longPressStart != 0) {
        gameOver();
      }

      // なんとなくオーバーフロー対策
      if (count > pow(2, 30)){
        count = 0;
      }
      count++;

      // レベルに応じて、難易度を上昇
      if (score > level * level * 10000 && !widget.endlessMode) {
        if (birthRate > 1) {
          birthRate--;
        }
        maxStar++;
        level++;
      }
      // twinkle mode では画面を触っている間、星を出し続ける
      if (twinkleX > 0 && twinkleY > 0 && widget.twinkleMode && count % 2 == 0) {
        Star s = Star(
            x: twinkleX,
            y: twinkleY,
            size: 40,
            xSpeed: 0,
            ySpeed: 0,
            angle: 0,
            rotateSpeed: 0,
            meteoriteColor: 0
        );
        // 大きい星は出さない
        s.caughtMillSeconds = lastMilliseconds;
        createMeteorite(s, false);
        stars.add(s);
      }
      // ゲームオーバー時はスローモーションにするため、数フレーム描画をスキップ
      if (gameOverStart != 0) {
        // 最初の 0.5 秒間は画面を振動させる演出を入れる
        if (lastMilliseconds - gameOverStart < 500) {
          vibrationX = Random().nextInt(20) - 10;
          vibrationY = Random().nextInt(20) - 10;
          return;
        } else {
          vibrationX = 0;
          vibrationY = 0;
        }
        // 5フレームに1回だけ描画
        if (count % 5 != 0) {
          return;
        }
      }
      // 星の生成処理
      birthStar(containerWidth, containerHeight);
      // 星の移動 と 当たり判定
      tapAndMoveStar(duration, containerWidth, containerHeight, diffTime);
      // Meteorite と星の当たり判定
      collisionMeteorite(duration);
      // 星同士の当たり判定
      if (gameOverStart == 0 && !widget.endlessMode) {
        collisionStar(duration);
      }
      // 衝突から 3 秒でゲームオーバー表示
      if (gameOverStart != 0 && duration.inMilliseconds - gameOverStart > 3000) {
        gameOver();
      }
    });
    // ゲームオーバーになった場合は
    if (!isGameOver) {
      SchedulerBinding.instance.scheduleFrameCallback(frameCallback);
    }
  }


  /// 星が生まれる
  ///
  void birthStar(int w, int h){
    // 10 フレームに一度、確率計算を行い星を生成させる
    if ((count % 10 == 0 && Random().nextInt(birthRate) % birthRate == 0 && stars.length < maxStar)) {
      if (sounds) {
        cache.play(birthSoundPath);
      }
      int starSize = Random().nextInt(40) + 40;
      double rotateSpeed = (Random().nextInt(2) + 2)  * getSign().toDouble();
      Star s = Star(
          x: Random().nextInt(w - starSize).toDouble(),
          y: Random().nextInt(h - starSize).toDouble(),
          size: starSize,
          xSpeed: (Random().nextInt(400) - 200) / 100,
          ySpeed: (Random().nextInt(400) - 200) / 100,
          angle: Random().nextInt(360).toDouble(),
          rotateSpeed: rotateSpeed,
          meteoriteColor: 0
      );
      s.birthMillSeconds = lastMilliseconds;
      if (stars.isEmpty || widget.endlessMode) {
        s.invincible = false;
      }
      stars.add(s);
    }
  }

  /// タップとの当たり判定と星のフレームごとの移動処理を行う
  ///
  void tapAndMoveStar(Duration duration, int w, int h, int diffTime) {
    List<int> removeStars = <int>[];
    for (int i = stars.length - 1; i >= 0; i--) {
      Star star = stars[i];
      // 最初の3秒間は無敵モード
      if (lastMilliseconds - star.birthMillSeconds > (3000 - (level * 10))) {
        star.invincible = false;
      }
      // すでにキャッチされた星
      if (star.caughtMillSeconds != 0) {
        double diff = (lastMilliseconds - star.caughtMillSeconds) / 100;
        star.chainOffset = Offset(star.x,
            star.y - diff);
        for (int j = 0; j < star.meteorites.length; j++) {
          Star meteorite = star.meteorites[j];
          meteorite.x += meteorite.xSpeed * (diffTime / 20);
          meteorite.y += meteorite.ySpeed * (diffTime / 20);
          meteorite.angle += meteorite.rotateSpeed * (diffTime / 20);
        }
        // タップ後3秒で消える
        if (duration.inMilliseconds - star.caughtMillSeconds > 3000) {
          removeStars.add(i);
        }
        continue;
      }
      // 当たった
      if (star.x < tapX
          && star.x + star.size > tapX
          && star.y < tapY
          && star.y + star.size > tapY) {
        // 最大チェイン数を必要に応じて更新
        if (star.chain > chain) {
          chain = star.chain;
        }
        star.chainOffset = Offset(star.x, star.y);
        star.caughtMillSeconds = duration.inMilliseconds;
        score += star.caughtMillSeconds - star.birthMillSeconds;
        createMeteorite(star, false);
      }
      // 星の移動距離
      double nextX = star.x + star.xSpeed * (diffTime / 20);
      double nextY = star.y + star.ySpeed * (diffTime / 20);

      // 画面外に星が出ないように、方向を逆転させる
      if (nextX < 0 || nextX > w - star.size) {
        star.xSpeed = -(star.xSpeed);
        nextX = star.x + star.xSpeed * (diffTime / 20);
      }
      if (nextY < 0 || nextY > h - star.size) {
        star.ySpeed = -(star.ySpeed);
        nextY = star.y + star.ySpeed * (diffTime / 20);
      }
      star.x = nextX;
      star.y = nextY;

      // 星の回転角を更新
      star.angle += star.rotateSpeed * (diffTime / 20);
      if (star.angle > 360) {
        star.angle = 0;
      }
      if (star.angle < 0) {
        star.angle = 360;
      }
    }
    for (int number in removeStars) {
      stars.removeAt(number);
    }
    // 初期化
    tapX = -1;
    tapY = -1;
  }

  /// 星と隕石の衝突判定を行う
  ///
  void collisionMeteorite(Duration duration){
    for (int i = 0; i < stars.length; i++) {
      Star star = stars[i];
      if (star.caughtMillSeconds == 0 || star.isCollision) {
        continue;
      }
      for (int j = 0; j < star.meteorites.length; j++) {
        Star meteorite = star.meteorites[j];
        for (int k = 0; k < stars.length; k++) {
          if (i == k) {
            continue;
          }
          Star starNext = stars[k];
          if (starNext.caughtMillSeconds != 0) {
            continue;
          }
          if (calcCollision(meteorite, starNext)){
            starNext.caughtMillSeconds = duration.inMilliseconds;
            starNext.chain += star.chain;
            score += (starNext.caughtMillSeconds - starNext.birthMillSeconds) * starNext.chain * level;
            if (starNext.chain > chain) {
              chain = starNext.chain;
            }
            starNext.chainOffset = Offset(starNext.x, starNext.y);
            createMeteorite(starNext, false);
          }
        }
      }
    }
  }

  /// 星同士の当たり判定をチェック
  ///
  void collisionStar(Duration duration) {
    for (int i = 0; i < stars.length; i++) {
      Star star = stars[i];
      if (star.caughtMillSeconds != 0) {
        continue;
      }
      // 無敵の星はスルー
      if (star.invincible) {
        continue;
      }
      for (int j = i + 1; j < stars.length; j++) {
        Star starNext = stars[j];
        if (starNext.caughtMillSeconds != 0) {
          continue;
        }
        // 無敵の星はスルー
        if (starNext.invincible) {
          continue;
        }
        if (calcCollision(star, starNext)) {
          star.isCollision = true;
          starNext.isCollision = true;
          star.caughtMillSeconds = duration.inMilliseconds;
          starNext.caughtMillSeconds = duration.inMilliseconds;
          createMeteorite(star, true);
          createMeteorite(starNext, true);
          if (sounds) {
            cache.play(bombSoundPath);
          }
          gameOverStart = lastMilliseconds;
        }
      }
    }
  }

  /// 星同士の当たり座標計算
  ///
  bool calcCollision(Star starA, Star starB) {
    return starA.x < starB.x + starB.size - 20
        && starA.x + starA.size > starB.x + 20
        && starA.y < starB.y + starB.size - 20
        && starA.y + starA.size > starB.y + 20;
  }

  /// 星破壊時にランダムで小さい星を生成する
  ///
  void createMeteorite(Star star, bool gameOver) {
    Future(() async {
      if (gameOverStart == 0 && sounds) {
        cache.play(starSoundPath);
      }
    });
    int meteoriteNum = Random().nextInt(5) + 5;
    for (int j = 0; j < meteoriteNum; j++) {
      double starHalfSize = star.size / 2;
      int meteoriteSize = Random().nextInt(10) + 10;
      double meteoriteX = Random().nextInt(star.size) + star.x;
      double meteoriteY = Random().nextInt(star.size) + star.y;
      double rotateSpeed = (Random().nextInt(10) + 5)  * getSign().toDouble();
      Star s = Star(
          x: meteoriteX,
          y: meteoriteY,
          size: meteoriteSize,
          xSpeed: (meteoriteX - (star.x + starHalfSize)) / 30,
          ySpeed: (meteoriteY - (star.y + starHalfSize)) / 30,
          angle: Random().nextInt(360).toDouble(),
          rotateSpeed: rotateSpeed, // 回転速度
          meteoriteColor: gameOver ? 3 :Random().nextInt(2) + 1 // 色
      );
      star.meteorites.add(s);
    }
  }

  /// ゲームオーバー時の振る舞い
  ///
  void gameOver(){
    if (!isGameOver && !widget.endlessMode){
      if (score > highScore) {
        isHighScore = true;
        prefs.setInt('_score', score);
      }
      if (chain > maxChain) {
        prefs.setInt('_chain', chain);
      }
    }
    isGameOver = true;
  }

  /// 1 or -1 をランダムで返す
  ///
  int getSign(){
    return (Random().nextInt(2) == 0 ? 1 : -1);
  }
  @override
  void initState() {
    cache.loadAll([starSoundPath, bombSoundPath, birthSoundPath]);
    if (widget.endlessMode) {
      maxStar = 100;
      birthRate = 15;
    }
    if (widget.twinkleMode) {
      modeName = "Twinkle Mode";
    }
    Future(() async {
      final star = await rootBundle.load("assets/images/star.png");
      final starList = Uint8List.view(star.buffer);
      ui.decodeImageFromList(starList, (img) {
        starYellow = img;
      });
      final pink = await rootBundle.load("assets/images/star_pink.png");
      final pinkList = Uint8List.view(pink.buffer);
      ui.decodeImageFromList(pinkList, (img) {
        meteoriteRed = img;
      });
      final blue = await rootBundle.load("assets/images/star_blue.png");
      final blueList = Uint8List.view(blue.buffer);
      ui.decodeImageFromList(blueList, (img) {
        meteoriteBlue = img;
      });
      final red = await rootBundle.load("assets/images/star_red.png");
      final redList = Uint8List.view(red.buffer);
      ui.decodeImageFromList(redList, (img) {
        starRed = img;
      });
     
      prefs = await SharedPreferences.getInstance();
      setState(() {
        highScore = (prefs.getInt('_score') ?? 0);
        maxChain = (prefs.getInt('_chain') ?? 0);
        sounds = (prefs.getBool('_sounds') ?? false);
      });
    });
    super.initState();
    SchedulerBinding.instance.scheduleFrameCallback(frameCallback);
  }

  void tapBack(BuildContext context){
    Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) {
    Widget gameWidget = isGameOver
        ? Center(child: Column(
        children:<Widget>[
          Expanded(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10.0),
                    child: Text(isHighScore?'High Score!':'',
                      style: const TextStyle(color: Colors.blueAccent,fontSize: 20, fontFamily: "senobi_regular"),),
                  ),
                  Container(
                    margin: const EdgeInsets.only(bottom: 10.0),
                    child: Text(!widget.endlessMode ?'SCORE: ${formatter.format(score)}':'',
                      style: const TextStyle(color: Colors.black54,fontSize: 20),),
                  ),
                  ButtonTheme(
                      minWidth: 200.0,
                      height: 50.0,
                      child:ElevatedButton(onPressed:(){
                        tapBack(context);
                      },
                        style: ElevatedButton.styleFrom(
                          primary: Colors.black54, // background
                          onPrimary: Colors.white, // foreground
                        ),
                        child: const Text('GAME OVER',
                          style: TextStyle(color: Colors.white,fontSize: 20),),
                      )),
                ]),
          ),
        ]))
        : Stack(
        children:<Widget>[
          Container(
            key: _targetKey,
            decoration: const BoxDecoration(
                color: Colors.white
            ),
            child: Flex(
              direction: Axis.vertical,
              children: <Widget>[
                Expanded(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: GestureDetector(
                      onPanDown: (DragDownDetails details){
                        tapX = details.localPosition.dx;
                        tapY = details.localPosition.dy;
                        twinkleX = tapX;
                        twinkleY = tapY;
                      },
                      onPanUpdate: (DragUpdateDetails details){
                        tapX = details.localPosition.dx;
                        tapY = details.localPosition.dy;
                        twinkleX = tapX;
                        twinkleY = tapY;
                      },
                      onPanEnd: (DragEndDetails details) {
                        twinkleX = -1;
                        twinkleY = -1;
                      },
                      onTapUp: (TapUpDetails details) {
                        twinkleX = -1;
                        twinkleY = -1;
                      },
                      onLongPressStart: (LongPressStartDetails _) {
                        longPressStart = lastMilliseconds;
                        twinkleX = -1;
                        twinkleY = -1;
                      },
                      onLongPressEnd: (LongPressEndDetails _) {
                        longPressStart = 0;
                        twinkleX = -1;
                        twinkleY = -1;
                      },
                      child: CustomPaint(
                        painter: PaintCanvas(
                            stars: stars,
                            starYellow: starYellow,
                            meteoriteRed: meteoriteRed,
                            meteoriteBlue: meteoriteBlue,
                            starRed: starRed,
                            vibrationX: vibrationX,
                            vibrationY: vibrationY,
                            endlessMode: widget.endlessMode),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
              left: 10.0,
              top: 30.0,
              child: widget.endlessMode ?
              Column(
                  children: [
                    Container(
                      height: 20.0,
                      decoration: const BoxDecoration(color: Color.fromARGB(0, 0, 0, 0)),
                      child: longPressStart == 0 ?
                      Text('$modeName (画面を $longPressFinishSeconds 秒長押しで終了)',textAlign: TextAlign.left,)
                          : Text('あと ${(longPressFinishSeconds * 1000 - (lastMilliseconds - longPressStart)) ~/ 1000} 秒長押しで終了',textAlign: TextAlign.left,),
                    )]
              ):
              Column(
                  children: [
                    Container(
                      height: 20.0,
                      width: 300,
                      decoration: const BoxDecoration(color: Color.fromARGB(0, 0, 0, 0)),
                      child: Text('LEVEL: $level',textAlign: TextAlign.left,),
                    ),
                    Container(
                      height: 20.0,
                      width: 300,
                      decoration: const BoxDecoration(color: Color.fromARGB(0, 0, 0, 0)),
                      child: Text('SCORE: ${formatter.format(score)}',textAlign: TextAlign.left,),
                    ),
                    Container(
                      height: 20.0,
                      width: 300,
                      decoration: const BoxDecoration(color: Color.fromARGB(0, 0, 0, 0)),
                      child: Text('CHAIN: $chain',textAlign: TextAlign.left,),
                    )
                  ]

              )
          ),]
    );

    return Scaffold(
        primary: false,
        body: SafeArea(child: gameWidget));
  }
}

// キャンバス
class PaintCanvas extends CustomPainter{

  final List<Star> stars;
  final ui.Image? starYellow;
  final ui.Image? starRed;
  final ui.Image? meteoriteRed;
  final ui.Image? meteoriteBlue;
  // ゲームオーバー時の画面の振動
  final int vibrationX;
  final int vibrationY;
  final bool endlessMode;

  PaintCanvas({
    required this.stars,
    required this.starYellow,
    required this.meteoriteRed,
    required this.meteoriteBlue,
    required this.starRed,
    required this.vibrationX,
    required this.vibrationY,
    required this.endlessMode});

  @override
  void paint(Canvas canvas, Size size) {

    Paint paint = Paint();
    Paint alphaPaint = Paint()
      ..color = const Color.fromRGBO(0, 0, 0, 0.2);
    canvas.save();
    for (int i = 0; i < stars.length; i++) {
      Star star = stars[i];
      double x = star.x + vibrationX;
      double y = star.y + vibrationX;
      // 捕まっていない星、もしくは衝突した星を描画
      if (star.caughtMillSeconds == 0 || star.isCollision) {
        Offset center = Offset(x + star.size / 2, y + star.size / 2);
        Rect dstRect = Rect.fromLTWH(x, y, star.size.toDouble(), star.size.toDouble());
        drawRotatedImage(canvas, center, starYellow!, star.angle, dstRect, star.invincible ? alphaPaint : paint);
      }
    }
    for (int i = 0; i < stars.length; i++) {
      Star star = stars[i];
      // 捕まった星は隕石を表示
      if (star.caughtMillSeconds != 0) {
        for (int j = 0; j < star.meteorites.length; j++) {
          Star meteorite = star.meteorites[j];
          double dx = meteorite.x + vibrationX;
          double dy = meteorite.y + vibrationX;
          Offset center = Offset(dx + meteorite.size / 2, dy + meteorite.size / 2);
          Rect dstRect = Rect.fromLTWH(dx, dy, meteorite.size.toDouble(), meteorite.size.toDouble());
          ui.Image meteoriteImage = meteorite.meteoriteColor == 1 ? meteoriteRed! :
                                 meteorite.meteoriteColor == 2 ? meteoriteBlue! : starRed!;
          drawRotatedImage(
              canvas,
              center,
              meteoriteImage,
              meteorite.angle,
              dstRect,
              paint);
        }
        if (!endlessMode && !star.isCollision) {
          // 連鎖数を表示
          drawText(
              canvas,
              size,
              star.chainOffset,
              star.chain
          );
        }
      }

    }

    canvas.restore();
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
  void drawRotatedImage(
      Canvas canvas,
      Offset center,
      ui.Image image,
      double angle,
      Rect dstRect,
      Paint p
      ) {
    // 画像を回転させて描画する方法がないので、キャンバス自体を回転させて描画する
    Rect imageRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle * (pi / 180));
    canvas.translate(-center.dx, -center.dy);
    canvas.drawImageRect(image, imageRect, dstRect, p);
    canvas.restore();
  }
  // キャンバスに文字列を描画
  void drawText(Canvas canvas, Size size, Offset offset, int number){
    const textStyle = TextStyle(
      color: Colors.redAccent,
      fontSize: 10,
    );
    final textSpan = TextSpan(
      text: "$number Chain!",
      style: textStyle,
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout(
      minWidth: 0,
      maxWidth: size.width,
    );
    textPainter.paint(canvas, offset);
  }
}

