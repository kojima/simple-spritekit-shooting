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
    
    private var spaceship : SKSpriteNode = SKSpriteNode(imageNamed: "spaceship01")
    private var motionManager: CMMotionManager = CMMotionManager()
    private var beamCount = 0

    override func didMove(to view: SKView) {

        backgroundColor = SKColor(red: 44.0 / 255.0, green: 62.0 / 255.0, blue: 80.0 / 255.0, alpha: 1.0)

        spaceship.anchorPoint = CGPoint(x: 0.5, y: 0)
        spaceship.position = CGPoint(x: view.frame.width * 0.5, y: 16)
        addChild(spaceship)

        let starFront = SKSpriteNode(imageNamed: "star_front")
        starFront.anchorPoint = CGPoint(x: 0, y: 0)
        starFront.position = CGPoint(x: 0, y: 0)
        starFront.zPosition = -1
        addChild(starFront)

        let starFrontActionMove = SKAction.moveBy(x: 0, y: -size.height, duration: 4)
        let starFrontsActionReset = SKAction.moveBy(x: 0, y: size.height, duration: 0)
        starFront.run(SKAction.repeatForever(
            SKAction.sequence([starFrontActionMove, starFrontsActionReset])
        ))

        let starBack = SKSpriteNode(imageNamed: "star_back")
        starBack.anchorPoint = CGPoint(x: 0, y: 0)
        starBack.position = CGPoint(x: 0, y: 0)
        starBack.zPosition = -2
        addChild(starBack)

        let starBackActionMove = SKAction.moveBy(x: 0, y: -size.height, duration: 6)
        let starBackActionReset = SKAction.moveBy(x: 0, y: size.height, duration: 0)
        starBack.run(SKAction.repeatForever(
            SKAction.sequence([starBackActionMove, starBackActionReset])
        ))

        run(SKAction.repeatForever(
            SKAction.playSoundFileNamed("bgm.mp3", waitForCompletion: true)
        ))

        motionManager.startAccelerometerUpdates()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if beamCount < 3 {
            let beam = SKSpriteNode(imageNamed: "beam")
            beam.anchorPoint = CGPoint(x: 0.5, y: 1)
            beam.position = CGPoint(x: spaceship.position.x, y: spaceship.position.y + spaceship.size.height)
            let action = SKAction.sequence([
                SKAction.playSoundFileNamed("beam.wav", waitForCompletion: false),
                SKAction.moveBy(x: 0, y: size.height, duration: 1.0),
                SKAction.run({ self.beamCount -= 1 }),
                SKAction.removeFromParent()
            ])
            beam.run(action)
            addChild(beam)
            beamCount += 1
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    }

    override func update(_ currentTime: TimeInterval) {
        if let data = motionManager.accelerometerData {
            if fabs(data.acceleration.x) > 0.05 || fabs(data.acceleration.y) > 0.05 {
                spaceship.position.x += 5 * (data.acceleration.x > 0 ? 1 : -1)
                spaceship.position.y += 5 * (data.acceleration.y > 0 ? 1 : -1)
            }
        }
        if spaceship.position.x < spaceship.size.width * 0.5 {
            spaceship.position.x = spaceship.size.width * 0.5
        } else if spaceship.position.x > size.width - spaceship.size.width * 0.5 {
            spaceship.position.x = size.width - spaceship.size.width * 0.5
        }
        if spaceship.position.y < 0 {
            spaceship.position.y = 0
        } else if spaceship.position.y > size.height - spaceship.size.height {
            spaceship.position.y = size.height - spaceship.size.height
        }
    }
}
