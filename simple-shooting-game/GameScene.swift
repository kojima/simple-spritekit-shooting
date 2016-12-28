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
    private var beamCount = 0   // ビームの発射数: 同時発射数を最大3発に制限するためのカウンター
    private var lastEnemySpawnedTime: TimeInterval = 0

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

        if currentTime - lastEnemySpawnedTime > Double(3 + arc4random_uniform(3)) {
            spawnEnemy()
            lastEnemySpawnedTime = currentTime
        }
    }

    private func spawnEnemy() {
        let enemy = SKSpriteNode(imageNamed: "enemy_ship")
        enemy.anchorPoint = CGPoint(x: 0.5, y: 0)
        enemy.position.x = size.width * 0.25 + CGFloat(arc4random_uniform(UInt32(Int(size.width * 0.5))))
        enemy.position.y = size.height
        enemy.zPosition = 110
        let verticalAction = SKAction.sequence([
            SKAction.playSoundFileNamed("enemy_spawn.wav", waitForCompletion: false),
            SKAction.moveBy(x: 0, y: -(size.height + enemy.size.height), duration: TimeInterval(Int(3 + arc4random_uniform(3)))),
            SKAction.removeFromParent()
        ])
        let horizontalAction = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.wait(forDuration: 0.5, withRange: 2),
                SKAction.run({
                    enemy.run(SKAction.moveBy(x: 50.0 - CGFloat(arc4random_uniform(100)), y: 0, duration: 0.5))
                })
            ])
        )
        let beamAction = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.wait(forDuration: 1, withRange: 3),
                SKAction.run({
                    self.spawnEnemyBeam(enemy: enemy);
                })
            ])
        )
        enemy.run(SKAction.group([verticalAction, horizontalAction, beamAction]))
        addChild(enemy)
    }

    private func spawnEnemyBeam(enemy: SKSpriteNode) {
        let beam = SKSpriteNode(imageNamed: "enemy_beam")
        beam.anchorPoint = CGPoint(x: 0.5, y: 0)
        beam.position = enemy.position
        beam.zPosition = enemy.zPosition - 1
        let action = SKAction.sequence([
            SKAction.playSoundFileNamed("enemy_beam.wav", waitForCompletion: false),
            SKAction.moveBy(x: 0, y: -size.height, duration: 0.75),
            SKAction.removeFromParent()
        ])
        beam.run(action)
        addChild(beam)
    }
}
