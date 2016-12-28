# シューティングゲーム
SpriteKitを使って、簡単なシューティングゲームを作成します。<br/>

<img height="320" alt="ゲーム画面" src="https://github.com/kojima/simple-spritekit-shooting/blob/master/screenshots/sh01.png"/><br/>
* 画面をタップすると、<a href="http://opengameart.org/content/space-shooter-art">スペースシップ(プレイヤー)</a>からビームが発射されます。
* スペースシップは、端末を傾けて操作します。
* 一度に発射できるビームを3発に制限します。
* ビーム発射の際に、<a href="http://www.freesound.org/people/MusicLegends/sounds/344310/">発射音</a>が鳴るようにします。
* <a href="http://www.freesound.org/people/orangefreesounds/sounds/326479/">BGM</a>もループ再生します。
* SpriteKitのSKSpriteNodeやSKAction等、基本的な要素を使用して実現しています。

++++++++++++++++++++++++++++++
最初は、<a href="https://github.com/kojima/simple-spritekit-shooting/tree/step01">"Step 1"</a>から作り始めます
++++++++++++++++++++++++++++++

# ビューコントローラー(`GameViewController.swift`)
``` swift
//
//  GameViewController.swift
//  simple-shooting-game
//
//  Created by Hidenori Kojima on 2016/12/27.
//  Copyright © 2016年 Hidenori Kojima. All rights reserved.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        if let view = self.view as! SKView? {
            // Load the SKScene from 'GameScene.sks'
            let scene = GameScene(size: view.frame.size)
            // Set the scale mode to scale to fit the window
            scene.scaleMode = .aspectFit

            // Present the scene
            view.presentScene(scene)

            view.ignoresSiblingOrder = true

            view.showsFPS = true
            view.showsNodeCount = true
        }
    }

    override var shouldAutorotate: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
```

# メインコード(`GameScene.swift`)
``` swift
//
//  GameScene.swift
//  simple-shooting-game
//
//  Created by Hidenori Kojima on 2016/12/27.
//  Copyright © 2016年 Hidenori Kojima. All rights reserved.
//

import SpriteKit
import GameplayKit
import CoreMotion

class GameScene: SKScene {

    private var player : SKSpriteNode = SKSpriteNode(imageNamed: "spaceship01")  // プレイヤー (スペースシップ)
    private var motionManager: CMMotionManager = CMMotionManager()               // モーションマネージャー: iPadの傾きを検出する
    private var beamCount = 0                           // ビームの発射数: 同時発射数を最大3発に制限するためのカウンター
    private var lastEnemySpawnedTime: TimeInterval = 0  // 最後に敵を生成した時刻を保持するための変数

    override func didMove(to view: SKView) {

        // 画面をミッドナイトブルー(red = 44, green = 62, blue = 80)に設定する
        // 色参照: https://flatuicolors.com/
        backgroundColor = SKColor(red: 44.0 / 255.0, green: 62.0 / 255.0, blue: 80.0 / 255.0, alpha: 1.0)

        // プレイヤーを画面中央下側に配置する
        player.anchorPoint = CGPoint(x: 0.5, y: 0)
        player.position = CGPoint(x: view.frame.width * 0.5, y: 16) // スプライトの中央下位置を原点とする
        player.zPosition = 100                                      // プレイヤーを最前面に配置する
        addChild(player)                                            // シーンにプレイヤーを追加する

        // 星背景(前面)を配置する
        let starFront = SKSpriteNode(imageNamed: "star_front")
        starFront.anchorPoint = CGPoint(x: 0, y: 0) // 星背景(前面)の左下を原点とする
        starFront.position = CGPoint(x: 0, y: 0)    // シーンの左下に配置する
        starFront.zPosition = 10                    // プレイヤーよりも背面に配置する
        addChild(starFront)                         // シーンに星背景(前面)を追加する

        // 星背景(前面)を下方向にシーンの高さ分だけ4秒間で移動し、その後に元の位置に戻す
        // アクションを追加する
        let starFrontActionMove = SKAction.moveBy(x: 0, y: -size.height, duration: 4)
        let starFrontsActionReset = SKAction.moveBy(x: 0, y: size.height, duration: 0)
        starFront.run(SKAction.repeatForever(
            SKAction.sequence([starFrontActionMove, starFrontsActionReset])
        ))

        // 星背景(後面)を配置する
        let starBack = SKSpriteNode(imageNamed: "star_back")
        starBack.anchorPoint = CGPoint(x: 0, y: 0)  // 星背景(後面)の左下を原点とする
        starBack.position = CGPoint(x: 0, y: 0)     // シーンの左下に配置する
        starBack.zPosition = 1                      // 星背景(前面)よりも背面に配置する
        addChild(starBack)                          // シーンに星背景(後面)を追加する

        // 星背景(後面)を下方向にシーンの高さ分だけ6秒間で移動し、その後に元の位置に戻す
        // アクションを追加する
        // 星背景(前面)よりも移動時間を長くすることで、背景に奥行きが感じられるようになる
        let starBackActionMove = SKAction.moveBy(x: 0, y: -size.height, duration: 6)
        let starBackActionReset = SKAction.moveBy(x: 0, y: size.height, duration: 0)
        starBack.run(SKAction.repeatForever(
            SKAction.sequence([starBackActionMove, starBackActionReset])
        ))

        // BGMをループ再生する
        run(SKAction.repeatForever(
            SKAction.playSoundFileNamed("bgm.mp3", waitForCompletion: true)
        ))

        // iPadの傾き検出を開始する
        motionManager.startAccelerometerUpdates()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // 現在のビーム発射数が3発に達していない場合、ビームを発射する
        if beamCount < 3 {
            // ビーム用のスプライトを生成する
            let beam = SKSpriteNode(imageNamed: "beam")
            beam.anchorPoint = CGPoint(x: 0.5, y: 1)
            beam.position = CGPoint(x: player.position.x, y: player.position.y + player.size.height)    // プレイヤーの先頭にビームを配置する
            beam.zPosition = 90 // プレイヤースプライトの背面に配置する
            // ビーム用スプライトに以下のアクションを追加する:
            // 1. ビーム発射音を再生する
            // 2. シーンの高さの分だけ0.5秒で前に進む
            // 3. ビーム発射数を1つ減らす
            // 4. ビーム用スプライトをシーンから削除する
            let action = SKAction.sequence([
                SKAction.playSoundFileNamed("beam.wav", waitForCompletion: false),
                SKAction.moveBy(x: 0, y: size.height, duration: 0.5),
                SKAction.run({ self.beamCount -= 1 }),
                SKAction.removeFromParent()
            ])
            beam.run(action)    // ビームにアクションを追加する
            addChild(beam)      // ビームをシーンに追加する
            beamCount += 1      // ビーム発射数を1つ増やす
        }
    }

    override func update(_ currentTime: TimeInterval) {
        // iPadの傾きデータが取得できた場合、プレイヤーをコントロールする
        if let data = motionManager.accelerometerData {
            // iPadの横方向の傾きが一定以上だった場合、傾き量に応じてプレイヤーを横方向に移動させる
            if fabs(data.acceleration.x) > 0.2 {
                player.position.x += 5 * (data.acceleration.x > 0 ? 1 : -1)
            }
            // iPadの縦方向の傾きが一定以上だった場合、傾き量に応じてプレイヤーを縦方向に移動させる
            if fabs(data.acceleration.y) > 0.2 {
                player.position.y += 5 * (data.acceleration.y > 0 ? 1 : -1)
            }
        }
        if player.position.x < player.size.width * 0.5 {                    // プレイヤーが画面左端よりも左に移動してしまったら、画面左端に戻す
            player.position.x = player.size.width * 0.5
        } else if player.position.x > size.width - player.size.width * 0.5 {// プレイヤーが画面右端よりも右に移動してしまったら、画面右端に戻す
            player.position.x = size.width - player.size.width * 0.5
        }
        if player.position.y < 0 {                                          // プレイヤーが画面下端よりも下に移動してしまったら、画面下端に戻す
            player.position.y = 0
        } else if player.position.y > size.height - player.size.height {    // プレイヤーが画面上端よりも上に移動してしまったら、画面上端に戻す
            player.position.y = size.height - player.size.height
        }

        // ランダムな間隔(3秒〜6秒)で敵を発生させる
        if currentTime - lastEnemySpawnedTime > TimeInterval(3 + arc4random_uniform(3)) {
            spawnEnemy()                        // 敵を生成する
            lastEnemySpawnedTime = currentTime  // 最終敵生成時刻を更新する
        }
    }

    // 敵を生成するメソッド
    private func spawnEnemy() {
        let enemy = SKSpriteNode(imageNamed: "enemy_ship")  // 敵のスプライトを作成する
        enemy.anchorPoint = CGPoint(x: 0.5, y: 0)           // 敵スプライトの中央下側を原点とする
        enemy.position.x = size.width * (0.25 + CGFloat(arc4random_uniform(5)) / 10.0)  // 敵の横方向の位置をシーン幅の1/4〜3/4の間の値にする
        enemy.position.y = size.height                                                  // 敵の縦方向の位置をシーン上端にする
        enemy.zPosition = player.zPosition + 10 // 敵スプライトをプレイヤーより前面に表示する
        // 敵スプライトの縦方向のアクションを定義する:
        //   1. 敵発生音を再生する
        //   2. (シーン縦幅 + 敵スプライト高さ)分の距離を縦方向に3〜6秒の時間(ランダム時間)で移動する
        //   3. 敵スプライトをシーンから削除する
        let verticalAction = SKAction.sequence([
            SKAction.playSoundFileNamed("enemy_spawn.wav", waitForCompletion: false),
            SKAction.moveBy(x: 0, y: -(size.height + enemy.size.height), duration: TimeInterval(Int(3 + arc4random_uniform(3)))),
            SKAction.removeFromParent()
        ])
        // 敵スプライトの横方向のアクションを定義する:
        //   以下の操作をずっと繰り返す:
        //     1. 0.5〜2秒(ランダム時間)待つ
        //     2. -50〜50の距離(ランダム距離)を縦方向に0.5秒で移動する
        let horizontalAction = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.wait(forDuration: 0.5, withRange: 2),
                SKAction.run({
                    enemy.run(SKAction.moveBy(x: 50.0 - CGFloat(arc4random_uniform(100)), y: 0, duration: 0.5))
                })
            ])
        )
        // 敵スプライトからビームを発射するアクションを定義する
        //   以下の操作をずっと繰り返す:
        //     1. 1〜3秒(ランダム時間)待つ
        //     2. ビーム発射メソッドを実行する
        let beamAction = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.wait(forDuration: 1, withRange: 3),
                SKAction.run({
                    self.spawnEnemyBeam(enemy: enemy);
                })
            ])
        )
        enemy.run(SKAction.group([verticalAction, horizontalAction, beamAction]))   // 上の3つのアクションを並行して実行する
        addChild(enemy) // 敵スプライトをシーンに追加する
    }

    // 敵のビームを生成するメソッド
    private func spawnEnemyBeam(enemy: SKSpriteNode) {
        let beam = SKSpriteNode(imageNamed: "enemy_beam")   // 敵ビームのスプライトを作成する
        beam.anchorPoint = CGPoint(x: 0.5, y: 0)            // 敵ビームスプライトの中央下側を原点とする
        beam.position = enemy.position                      // 敵スプライトと同じ位置に配置する
        beam.zPosition = enemy.zPosition - 1                // 敵スプライトの背面にビームを配置する
        // ビーム用に以下のアクションを定義する:
        //   1. 敵ビーム発射音を再生する
        //   2. シーンの高さ分の距離だけ縦方向に0.75秒かけて移動する
        //   3. 敵ビームスプライトをシーンから削除する
        let action = SKAction.sequence([
            SKAction.playSoundFileNamed("enemy_beam.wav", waitForCompletion: false),
            SKAction.moveBy(x: 0, y: -size.height, duration: 0.75),
            SKAction.removeFromParent()
        ])
        beam.run(action)    // 上記アクションを実行する
        addChild(beam)      // 敵ビームをシーンに追加する
    }
}
```

# 使用ゲームアセット
## 画像
* <a href="http://opengameart.org/content/space-shooter-art">スペースシップ/ビーム/敵</a>

## サウンド
* <a href="http://www.freesound.org/people/MusicLegends/sounds/344310/">ビーム音</a>
* <a href="http://www.freesound.org/people/alpharo/sounds/186696/">敵発生音</a>
* <a href="http://www.freesound.org/people/Heshl/sounds/269170/">敵ビーム音</a>
* <a href="http://www.freesound.org/people/orangefreesounds/sounds/326479/">BGM</a>
