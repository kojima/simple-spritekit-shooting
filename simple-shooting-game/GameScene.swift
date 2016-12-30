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
import AVFoundation

class GameScene: SKScene, SKPhysicsContactDelegate {

    // ゲームの状態を管理するための列挙型を定義する
    private enum GameState {
        case Playing                // プレイ中
        case GameWin                // ゲームクリア
        case GameOver               // ゲームオーバー
        case WaitToRestartFromWin   // ゲームクリアからのリスタート待ち
        case WaitToRestartFromLose  // ゲームオーバーからのリスタート待ち
    }

    // ゲームの残り距離を表示するためのクラスを定義する
    private class DistanceMeter: SKSpriteNode {
        let currentMeter = SKSpriteNode()

        convenience init(size: CGSize) {
            self.init(texture: nil, color: SKColor.white, size: size)
            // 現在の進行距離を表示するためのメーターをセットアップする
            currentMeter.size = CGSize(width: size.width, height: 0)
            currentMeter.color = SKColor(red: 26 / 255.0, green: 188 / 255.0, blue: 156 / 255.0, alpha: 1.0)
            currentMeter.anchorPoint = CGPoint.zero
            addChild(currentMeter)
        }

        // 進行距離をアップデートするメソッド
        func update(_ distance: Double) {
            currentMeter.size = CGSize(width: size.width, height: size.height * CGFloat(distance / 100.0))
        }
    }

    private var player : SKSpriteNode = SKSpriteNode(imageNamed: "spaceship01")     // プレイヤー (スペースシップ)
    private var motionManager: CMMotionManager = CMMotionManager()                  // モーションマネージャー: iPadの傾きを検出する
    private var beamCount = 0                                                       // ビームの発射数: 同時発射数を最大3発に制限するためのカウンター
    private var lastEnemySpawnedTime: TimeInterval = 0                              // 最後に敵を生成した時刻を保持するための変数
    private var bgm = AVAudioPlayer()                                               // BGMようのオーディオプレイヤー
    private var gameState = GameState.Playing                                       // ゲームの現在の状態
    private var gameWinTitle = SKSpriteNode(imageNamed: "game_win")                 // ゲームクリア用タイトル
    private var gameOverTitle = SKSpriteNode(imageNamed: "game_over")               // ゲームオーバー用タイトル
    private var restartButton = SKSpriteNode(imageNamed: "restart_button")          // リスタートボタン

    private let playerCategory: UInt32 = 0x1 << 0  // プレイヤーとプレイヤービームの衝突判定カテゴリを01(2進数)にする
    private let enemyCategory: UInt32 = 0x1 << 1   // 敵と敵ビームの衝突判定カテゴリを10(2進数)にする

    private let font  = BMGlyphFont(name:"88ZenFont")   // 88Zenフォント(スコア表記に使用する)
    private var scoreLabel: BMGlyphLabel!               // ゲームスコアを表示するためのラベル
    private var currentScore = 0                        // 現在のゲームスコア

    private var distanceMeter: DistanceMeter!           // ゲームの進行距離表示メーター
    private var gameStartTime: TimeInterval!            // ゲームのスタート時間

    override func didMove(to view: SKView) {

        // 画面をミッドナイトブルー(red = 44, green = 62, blue = 80)に設定する
        // 色参照: https://flatuicolors.com/
        backgroundColor = SKColor(red: 44.0 / 255.0, green: 62.0 / 255.0, blue: 80.0 / 255.0, alpha: 1.0)

        player.anchorPoint = CGPoint(x: 0.5, y: 0.5)                                        // スプライトの中心を原点とする
        player.position = CGPoint(x: size.width * 0.5, y: player.size.height * 0.5 + 16)    // プレイヤーを画面中央下側に配置する
        player.zPosition = 100                                                              // プレイヤーを最前面に配置する
        player.name = "player_ship"                                                         // プレイヤースプライトを"player_ship"と名付ける
        // プレイヤーの物理衝突の設定を行う
        player.physicsBody = SKPhysicsBody(rectangleOf: player.size)    // プレイヤー衝突用の物理ボディーを用意する
        player.physicsBody?.affectedByGravity = false                   // 重力の影響は受けないように設定
        player.physicsBody?.categoryBitMask = playerCategory            // 物理ボティーにプレイヤーの衝突判定カテゴリを設定
        player.physicsBody?.contactTestBitMask = enemyCategory          // 衝突検出対象を敵の衝突判定カテゴリに設定
        player.physicsBody?.collisionBitMask = 0                        // 衝突しても衝突相手からの力を受けないように設定
        addChild(player)    // シーンにプレイヤーを追加する

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

        // ゲームクリア用タイトルをセットアップする
        gameWinTitle.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5 + 80)     // シーン中央より少し上に配置する
        gameWinTitle.zPosition = 200                                                        // シーンの最前面に表示されるようにする

        // ゲームクリアの際のリスタートボタンをセットアップする
        restartButton.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5 - 88)    // シーンの中央より少し下に配置する
        restartButton.zPosition = 200                                                       // シーンの最前面に表示されるようにする

        // ゲームオーバー用タイトルをセットアップする
        gameOverTitle.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)         // シーン中央に配置する
        gameOverTitle.zPosition = 200                                                       // シーンの最前面に表示されるようにする

        // BGMをループ再生する
        let bgmUrl = URL(fileURLWithPath: Bundle.main.path(forResource: "bgm", ofType:"mp3")!)
        bgm = try! AVAudioPlayer(contentsOf: bgmUrl)
        bgm.numberOfLoops = -1  // ループ再生するように設定
        bgm.play()

        physicsWorld.contactDelegate = self     // 衝突判定を自分自身で行うように設定

        // iPadの傾き検出を開始する
        motionManager.startAccelerometerUpdates()

        // ゲームスコア用ラベルをセットアップする
        scoreLabel = BMGlyphLabel(txt: "スコア: \(currentScore)", fnt: font)     // ゲームスコア用ラベルを作成する
        scoreLabel.setHorizontalAlignment(.left)                                // ラベルの横方向基準点を左端にする
        scoreLabel.setVerticalAlignment(.top)                                   // ラベルの縦方向基準点を上端にする
        scoreLabel.position = CGPoint(x: 24, y: size.height - 16)               // ラベルをシーン左上に配置する
        addChild(scoreLabel)                                                    // ゲームスコア用ラベルをシーンに追加する

        // ゲームの進行距離表示メーターをセットアップする
        distanceMeter = DistanceMeter(size: CGSize(width: 16, height: size.height))
        distanceMeter.anchorPoint = CGPoint.zero                        // 原点を左下にする
        distanceMeter.position = CGPoint(x: size.width - 16, y: 0)      // シーンの左端に配置する
        addChild(distanceMeter)                                         // メーターをシーンに追加する
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if gameState == .WaitToRestartFromLose {        // ゲームの状態がゲームオーバーからのリスタート待ちの場合
            restart()
        } else if gameState == .WaitToRestartFromWin {  // ゲームの状態がゲームクリアからのリスタート待ちの場合
            if let touch = touches.first {
                let location = touch.location(in: self) //     タッチされた場所を取得する
                let touchedNode = atPoint(location)     //     タッチされた場所に位置するノードを取得する
                if touchedNode == restartButton {       //     タッチされたノードがリスタートボタンだった場合
                    run(SKAction.playSoundFileNamed("tap.wav", waitForCompletion: false))
                    restart()
                } else {                                //     それ以外の場所がタッチされた場合
                    fireBeam()
                }
            }
        } else if gameState == .Playing {               // ゲームの状態がプレイ中の場合
            fireBeam()
        }
    }

    override func update(_ currentTime: TimeInterval) {
        if gameState == .Playing {  // ゲームの状態がプレイ中の場合
            controlPlayer()

            // ランダムな間隔(3秒〜6秒)で敵を発生させる
            if currentTime - lastEnemySpawnedTime > TimeInterval(3 + arc4random_uniform(3)) {
                spawnEnemy()                        // 敵を生成する
                lastEnemySpawnedTime = currentTime  // 最終敵生成時刻を更新する
            }

            if gameStartTime == nil {                                   // ゲーム開始時刻が未設定の場合
                gameStartTime = currentTime                             //     現在の時刻をゲーム開始時刻に設定する
            } else {                                                    // 既にゲーム開始時刻が設定されている場合
                let currentDistance = (currentTime - gameStartTime) * 2 //     現在の距離を計算する
                distanceMeter.update(currentDistance)                   //     ゲームの進行距離表示メーターを更新する
                if currentDistance > 100 {                              //     進行距離が100を超えた場合
                    gameWin()                                           //         ゲームクリアの処理をする
                }
            }
        } else if gameState == .GameWin || gameState == .WaitToRestartFromWin { // ゲームの状態がゲームクリアまたはゲームクリアからのリスタート待ちの場合
            controlPlayer()
        }
    }

    // プレイヤーからのビームを発射を処理するメソッド
    private func fireBeam() {
        // 現在のビーム発射数が3発に達していない場合、ビームを発射する
        if beamCount < 3 {
            // ビーム用のスプライトを生成する
            let beam = SKSpriteNode(imageNamed: "beam")
            beam.anchorPoint = CGPoint(x: 0.5, y: 1)  // ビームの中央上側を原点とする
            beam.position = CGPoint(x: player.position.x, y: player.position.y + player.size.height * 0.5)    // プレイヤーの先頭にビームを配置する
            beam.zPosition = player.zPosition - 1   // プレイヤースプライトの背面に配置する
            beam.name = "player_beam"               // ビームスプライトを"player_beam"と名付ける
            // ビームの物理衝突の設定を行う
            beam.physicsBody = SKPhysicsBody(rectangleOf: beam.size)    // ビーム衝突用の物理ボディーを用意する
            beam.physicsBody?.affectedByGravity = false                 // 重力の影響は受けないように設定
            beam.physicsBody?.categoryBitMask = playerCategory          // 物理ボティーにプレイヤーの衝突判定カテゴリを設定
            beam.physicsBody?.contactTestBitMask = enemyCategory        // 衝突検出対象を敵の衝突判定カテゴリに設定
            beam.physicsBody?.collisionBitMask = 0                      // 衝突しても衝突相手からの力を受けないように設定

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

    // プレイヤー操作を処理するメソッド
    private func controlPlayer() {
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
        if player.position.x < player.size.width * 0.5 {                        // プレイヤーが画面左端よりも左に移動してしまったら、画面左端に戻す
            player.position.x = player.size.width * 0.5
        } else if player.position.x > size.width - player.size.width * 0.5 {    // プレイヤーが画面右端よりも右に移動してしまったら、画面右端に戻す
            player.position.x = size.width - player.size.width * 0.5
        }
        if player.position.y < player.size.height * 0.5 {                       // プレイヤーが画面下端よりも下に移動してしまったら、画面下端に戻す
            player.position.y = player.size.height * 0.5
        } else if player.position.y > size.height - player.size.height * 0.5 {  // プレイヤーが画面上端よりも上に移動してしまったら、画面上端に戻す
            player.position.y = size.height - player.size.height * 0.5
        }
    }

    // 敵を生成するメソッド
    private func spawnEnemy() {
        let enemy = SKSpriteNode(imageNamed: "enemy_ship")  // 敵のスプライトを作成する
        enemy.anchorPoint = CGPoint(x: 0.5, y: 0.5)         // 敵スプライトの中心を原点とする
        enemy.position.x = size.width * (0.25 + CGFloat(arc4random_uniform(5)) / 10.0)  // 敵の横方向の位置をシーン幅の1/4〜3/4の間の値にする
        enemy.position.y = size.height + enemy.size.height * 0.5                        // 敵の縦方向の位置をシーン上端にする
        enemy.zPosition = player.zPosition + 10 // 敵スプライトをプレイヤーより前面に表示する
        enemy.name = "enemy_ship"               // 敵スプライトを"enemy_ship"と名付ける
        // 敵の物理衝突の設定を行う
        enemy.physicsBody = SKPhysicsBody(rectangleOf: enemy.size)      // 敵衝突用の物理ボディを用意する
        enemy.physicsBody?.affectedByGravity = false                    // 重力の影響は受けないように設定
        enemy.physicsBody?.categoryBitMask = enemyCategory              // 物理ボティーに敵の衝突判定カテゴリを設定
        enemy.physicsBody?.contactTestBitMask = playerCategory          // 衝突検出対象をプレイヤーの衝突判定カテゴリに設定
        enemy.physicsBody?.collisionBitMask = 0                         // 衝突しても衝突相手からの力を受けないように設定


        // 敵スプライトの縦方向のアクションを定義する:
        //   1. 敵発生音を再生する
        //   2. (シーン縦幅 + 敵スプライト高さ)分の距離を縦方向に3〜6秒の時間(ランダム時間)で移動する
        //   3. 敵スプライトをシーンから削除する
        let verticalAction = SKAction.sequence([
            SKAction.playSoundFileNamed("enemy_spawn.wav", waitForCompletion: false),
            SKAction.moveBy(x: 0, y: -(size.height + enemy.size.height * 0.5), duration: TimeInterval(Int(3 + arc4random_uniform(3)))),
            SKAction.removeFromParent()
        ])
        // 敵スプライトの横方向のアクションを定義する:
        //   以下の操作をずっと繰り返す:
        //     1. 0.5〜2秒(ランダム時間)待つ
        //     2. -50〜50の距離(ランダム距離)を縦方向に0.5秒で移動する
        let horizontalAction = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.wait(forDuration: 0.5, withRange: 2),
                SKAction.run {
                    enemy.run(SKAction.moveBy(x: 50.0 - CGFloat(arc4random_uniform(100)), y: 0, duration: 0.5))
                }
            ])
        )
        // 敵スプライトからビームを発射するアクションを定義する
        //   以下の操作をずっと繰り返す:
        //     1. 1〜3秒(ランダム時間)待つ
        //     2. ビーム発射メソッドを実行する
        let beamAction = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.wait(forDuration: 1, withRange: 3),
                SKAction.run {
                    self.spawnEnemyBeam(enemy: enemy);
                }
            ])
        )
        enemy.run(SKAction.group([verticalAction, horizontalAction, beamAction]))   // 上の3つのアクションを並行して実行する
        addChild(enemy) // 敵スプライトをシーンに追加する
    }

    // 敵のビームを生成するメソッド
    private func spawnEnemyBeam(enemy: SKSpriteNode) {
        let beam = SKSpriteNode(imageNamed: "enemy_beam")   // 敵ビームのスプライトを作成する
        beam.anchorPoint = CGPoint(x: 0.5, y: 0)            // 敵ビームスプライトの中央下側を原点とする
        beam.position = CGPoint(x: enemy.position.x, y: enemy.position.y - enemy.size.height * 0.5)    // 敵スプライトの先端にビームを配置する
        beam.zPosition = enemy.zPosition - 1                // 敵スプライトの背面にビームを配置する
        beam.name = "enemy_beam"                            // 敵ビームスプライトを"enemy_beam"と名付ける
        // 敵ビームの物理衝突の設定を行う
        beam.physicsBody = SKPhysicsBody(rectangleOf: beam.size)    // 敵ビーム衝突用の物理ボディを用意する
        beam.physicsBody?.affectedByGravity = false                 // 重力の影響は受けないように設定
        beam.physicsBody?.categoryBitMask = enemyCategory           // 物理ボティーに敵の衝突判定カテゴリを設定
        beam.physicsBody?.contactTestBitMask = playerCategory       // 衝突検出対象をプレイヤーの衝突判定カテゴリに設定
        beam.physicsBody?.collisionBitMask = 0                      // 衝突しても衝突相手からの力を受けないように設定


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

    // プレイヤーと敵または敵ビームが接触したときに呼び出されるメソッド
    func didBegin(_ contact: SKPhysicsContact) {
        var player: SKNode!
        var enemy: SKNode!
        // 衝突した2つの物体(bodyA/bodyB)のうちどちらがプレイヤーカテゴリなのかをチェックする
        if contact.bodyA.categoryBitMask == playerCategory {
            player = contact.bodyA.node!    // 衝突した2体のうち、bodyAがプレイヤー側
            enemy = contact.bodyB.node!     // 衝突した2体のうち、bodyBが敵側
        } else if contact.bodyB.categoryBitMask == playerCategory {
            player = contact.bodyB.node!    // 衝突した2体のうち、bodyBがプレイヤー側
            enemy = contact.bodyA.node!     // 衝突した2体のうち、bodyAが敵側
        }
        if player.name == "player_ship" && (enemy.name == "enemy_ship" || enemy.name == "enemy_beam") { // プレイヤーが敵または敵ビームと衝突した場合
            explodePlayer(player)               // プレイヤーを爆発させる
            if enemy.name == "enemy_ship" {     // 敵側が敵機だった場合:
                explodeEnemy(enemy)             //   敵機も一緒に爆発させる
            } else {                            // 敵ビームだった場合:
                enemy.removeFromParent()        //   敵ビームをシーンから削除する
            }
        } else if player.name == "player_beam" && enemy.name == "enemy_ship" {  // プレイヤービームが敵と衝突した場合
            beamCount -= 1                      // 敵を爆破したビーム分だけビームカウントを減らす
            player.removeFromParent()           // ビームをシーンから削除する
            explodeEnemy(enemy)                 // 敵を爆発させる
        }
    }

    // プレイヤーを爆発させるメソッド
    private func explodePlayer(_ player: SKNode) {
        // プレイヤーで以下のアクションを実行する:
        // 1. プレイヤー爆発用サウンドを再生する
        // 2. プレイヤーをシーンから削除する
        player.run(SKAction.sequence([
            SKAction.playSoundFileNamed("explosion.wav", waitForCompletion: false),
            SKAction.removeFromParent()
        ]))
        // プレイヤー爆発用のスプライトをセットアップする
        let explosion = SKSpriteNode(imageNamed: "explosion")   // プレイヤー爆発用スプライトを作成する
        explosion.position = player.position                    // プレイヤーと同じ位置に配置する
        explosion.alpha = 0                                     // 最初はスプライトを透過度(アルファ)を透明にする
        explosion.setScale(0)                                   // 最初はスプライトの倍率(スケール)を0にする
        // プレイヤー爆発スプライトで以下の2つのアクションを並行して実行する:
        // 1. スプライトの倍率(スケール)を1倍(元の大きさ)にする
        // 2. 以下のアクションを順番に実行する:
        //   2-1. 0.2秒間でフェードインする
        //   2-2. 0.5秒待つ
        //   2-3. 1.5秒間でフェードアウトする
        //   2-4. プレイヤー爆発スプライトをシーンから削除する
        explosion.run(SKAction.group([
            SKAction.scale(to: 1.0, duration: 0.2),
            SKAction.sequence([
                SKAction.fadeIn(withDuration: 0.2),
                SKAction.wait(forDuration: 0.5),
                SKAction.fadeOut(withDuration: 1.5),
                SKAction.removeFromParent()
            ])
        ]))
        addChild(explosion) // プレイヤー爆発スプライトをシーンに追加する

        gameOver()
    }

    // 敵を爆発させるメソッド
    private func explodeEnemy(_ enemy: SKNode) {
        // 敵で以下のアクションを実行する:
        // 1. 敵爆発用サウンドを再生する
        // 2. 敵をシーンから削除する
        enemy.run(SKAction.sequence([
            SKAction.playSoundFileNamed("enemy_explosion.wav", waitForCompletion: false),
            SKAction.removeFromParent()
        ]))
        // 敵爆発用のスプライトをセットアップする
        let explosion = SKSpriteNode(imageNamed: "enemy_explosion") // 敵爆発用スプライトを作成する
        explosion.position = enemy.position                         // 敵と同じ位置に配置する
        explosion.alpha = 0                                         // 最初はスプライトを透過度(アルファ)を透明にする
        explosion.setScale(0)                                       // 最初はスプライトの倍率(スケール)を0にする
        // 敵爆発スプライトで以下の2つのアクションを並行して実行する:
        // 1. スプライトの倍率(スケール)を1倍(元の大きさ)にする
        // 2. 以下のアクションを順番に実行する:
        //   2-1. 0.2秒間でフェードインする
        //   2-2. 0.5秒待つ
        //   2-3. 1.5秒間でフェードアウトする
        //   2-4. 敵爆発スプライトをシーンから削除する
        explosion.run(SKAction.group([
            SKAction.scale(to: 1.0, duration: 0.2),
            SKAction.sequence([
                SKAction.fadeIn(withDuration: 0.2),
                SKAction.wait(forDuration: 0.5),
                SKAction.fadeOut(withDuration: 1.5),
                SKAction.removeFromParent()
            ])
        ]))
        addChild(explosion) // 敵爆発スプライトをシーンに追加する

        // スコアを更新する
        currentScore += 10                                  // スコアを10加点する
        scoreLabel.setGlyphText("スコア: \(currentScore)")   // スコアをゲームスコア用ラベルに反映させる
    }

    // ゲームクリアを処理するメソッド
    private func gameWin() {
        // 現在のゲームの状態がプレイ中でない場合は処理を抜ける
        if gameState != .Playing {
            return
        }

        // ゲームクリア時にシーン内に残っている敵機はすべて爆発させ、
        // 敵ビームはシーンから削除する
        for node in children {
            if node.name == "enemy_ship" {
                explodeEnemy(node)
            } else if node.name == "enemy_beam" {
                node.removeFromParent()
            }
        }

        gameState = .GameWin                                                    // ゲームの状態をゲームクリアにする
        run(SKAction.playSoundFileNamed("win.wav", waitForCompletion: false))   // ゲームクリア用サウンドを再生する
        gameWinTitle.alpha = 0  // ゲームクリアタイトルの透明度(アルファ)を透明にする
        // ゲームクリアタイトルで以下のアクションを実行する:
        // 1. 以下の処理を3回繰り返す:
        //   1-1. 0.2秒間でフェードイン
        //   1-2. 0.2秒間でフェードアウト
        // 2. 0.2秒間でフェードイン
        gameWinTitle.run(SKAction.sequence([
            SKAction.repeat(SKAction.sequence([
                SKAction.fadeIn(withDuration: 0.2),
                SKAction.fadeOut(withDuration: 0.2)
            ]), count: 3),
            SKAction.fadeIn(withDuration: 0.2)
        ]))
        addChild(gameWinTitle)  // ゲームクリア用のタイトルをシーンに追加する

        // 以下のアクションをシーンで実行する:
        // 1. 2.5秒間待つ
        // 2. 以下の処理を実行する:
        //   2-1. スコアラベルを画面中央に配置する
        //   2-2. リスタートボタンをシーンに追加する
        //   2-3. ゲームの状態をゲームクリアからのリスタート待ちにする
        run(SKAction.sequence([
            SKAction.wait(forDuration: 2.5),
            SKAction.run {
                self.scoreLabel.setHorizontalAlignment(.centered)
                self.scoreLabel.setVerticalAlignment(.middle)
                self.scoreLabel.position = CGPoint(x: self.size.width * 0.5, y: self.size.height * 0.5)
                self.addChild(self.restartButton)
                self.gameState = .WaitToRestartFromWin
            }
        ]))
    }

    // ゲームオーバーを処理するメソッド
    private func gameOver() {
        // ゲームの状態がプレイ中でなければ処理を抜ける
        if gameState != .Playing {
            return
        }

        gameState = .GameOver                   // ゲームの状態をゲームオーバーにする
        motionManager.stopDeviceMotionUpdates() // iPadの傾き検出を停止する

        // ゲームオーバーの演出を以下のアクションで実行する:
        // 1. 1.5秒間待つ
        // 2. BGMを停止する
        // 3. ゲームオーバー用サウンドを再生する
        // 4. 以下の処理を実行する:
        //   4-1. ゲームの状態をリスタート待ちにする
        //   4-2. ゲームオーバー用タイトルをシーンに追加する
        //   4-3. ゲームスコア用ラベルをシーンから削除する
        run(SKAction.sequence([
            SKAction.wait(forDuration: 1.5),
            SKAction.run {
                self.bgm.stop()
            },
            SKAction.playSoundFileNamed("lose.wav", waitForCompletion: true),
            SKAction.run {
                self.gameState = .WaitToRestartFromLose
                self.addChild(self.gameOverTitle)
                self.scoreLabel.removeFromParent()
            },
        ]))
    }

    // ゲームリスタートを処理するメソッド
    private func restart() {
        // ゲームの状態がリスタート待ちでなければ処理を抜ける
        if gameState != .WaitToRestartFromWin && gameState != .WaitToRestartFromLose {
            return
        }

        bgm.currentTime = 0                                 // BGMを先頭に戻す
        bgm.play()                                          // BGMを再生する
        currentScore = 0                                    // 現在のスコアを0点にリセットする
        scoreLabel.setGlyphText("スコア: \(currentScore)")   // スコアをゲームスコア用ラベルに反映する
        beamCount = 0                                       // ビームカウントを0にセットする
        distanceMeter.update(0)                             // ゲームの進行距離表示メーターをリセットする
        gameStartTime = nil                                 // ゲーム開始時刻を未設定にする
        motionManager.startAccelerometerUpdates()           // iPadの傾き検出を再開する
        if gameState == .WaitToRestartFromWin {                         // ゲームクリアからのリスタート待ちの場合
            gameWinTitle.removeFromParent()                             //     ゲームクリア用タイトルをシーンから削除する
            restartButton.removeFromParent()                            //     リスタートボタンをシーンから削除する
            scoreLabel.setHorizontalAlignment(.left)
            scoreLabel.setVerticalAlignment(.top)
            scoreLabel.position = CGPoint(x: 24, y: size.height - 16)   //     スコアラベルをシーン左上に配置し直す
        } else if gameState == .WaitToRestartFromLose {                 // ゲームオーバーからのリスタート待ちの場合
            gameOverTitle.removeFromParent()                            //     ゲームオーバー用タイトルをシーンから削除する
            player.position = CGPoint(x: size.width * 0.5, y: player.size.height * 0.5 + 16)    // プレイヤーを画面中央下側に配置する
            addChild(player)                                            //     プレイヤーを再度追加する
            addChild(scoreLabel)                                        //     ゲームスコア用ラベルをシーンに追加する
        }
        gameState = .Playing                                // ゲームの状態をプレイ中にする
    }
}
