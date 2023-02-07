import 'dart:ui';

class Star {
  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.xSpeed,
    required this.ySpeed,
    required this.angle,
    required this.rotateSpeed,
    required this.meteoriteColor});
  // 座標
  double x;
  double y;
  // 移動速度
  double xSpeed;
  double ySpeed;
  // サイズ
  int size;
  // 角度
  double angle;
  // 回転速度
  double rotateSpeed;
  // 無敵
  bool invincible = true;
  // 生まれた時間
  int birthMillSeconds = 0;
  // 捕まった時間（0 は生きている）
  int caughtMillSeconds = 0;
  // 捕まった後に飛び出す隕石
  List<Star> meteorites = <Star>[];
  // meteorite 色フラグ (0 は普通の星)
  // 1 は赤, 2 は青, 3 はゲームオーバー
  int meteoriteColor = 0;
  // 連鎖数
  int chain = 1;
  Offset chainOffset = const Offset(0, 0);
  // 衝突した星
  bool isCollision =  false;
}