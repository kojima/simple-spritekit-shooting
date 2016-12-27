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
    
    private var spaceship : SKSpriteNode?
    private var motionManager: CMMotionManager?

    override func didMove(to view: SKView) {

        backgroundColor = SKColor(red: 44.0 / 255.0, green: 62.0 / 255.0, blue: 80.0 / 255.0, alpha: 1.0)

        spaceship = SKSpriteNode(imageNamed: "spaceship01")
        spaceship?.anchorPoint = CGPoint(x: 0.5, y: 0)
        spaceship?.position = CGPoint(x: view.frame.width * 0.5, y: 16)
        addChild(spaceship!)

        motionManager = CMMotionManager()
        motionManager?.startAccelerometerUpdates()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    }

    override func update(_ currentTime: TimeInterval) {
        if let data = motionManager?.accelerometerData {
            if fabs(data.acceleration.x) > 0.1 || fabs(data.acceleration.y) > 0.1 {
                spaceship?.position.x += 5 * (data.acceleration.x > 0 ? 1 : -1)
                spaceship?.position.y += 5 * (data.acceleration.y > 0 ? 1 : -1)
            }
        }
    }
}
