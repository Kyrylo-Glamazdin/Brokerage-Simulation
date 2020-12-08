//
//  HudView.swift
//  MockInvestment
//
//  Created by Kyrylo Glamazdin on 11/30/20.
//

import Foundation
import UIKit

//This class is used to draw a simple animation on the screen when a certain transaction is completed
class HudView: UIView {
    var text = ""
    
    //configure the hud
    class func hud(inView view: UIView, animated: Bool) -> HudView {
        let hudView = HudView(frame: view.bounds)
        hudView.isOpaque = false
        
        view.addSubview(hudView)
        view.isUserInteractionEnabled = false
        
        hudView.show(animated: animated)
        return hudView
    }
    
    override func draw(_ rect: CGRect) {
        let boxWidth: CGFloat = 140
        let boxHeight: CGFloat = 140
        
        let boxRect = CGRect(
            x: round((bounds.size.width - boxWidth) / 2),
            y: round((bounds.size.height - boxHeight) / 2),
            width: boxWidth,
            height: boxHeight
        )
        
        //round the corners
        let roundedRect = UIBezierPath(roundedRect: boxRect, cornerRadius: 100)
        UIColor(white: 0.3, alpha: 0.8).setFill()
        roundedRect.fill()
        
        if let image = UIImage(named: "Checkmark") {
            let imagePoint = CGPoint(
                x: center.x - round(image.size.width / 2),
                y: center.y - round(image.size.height / 2) - boxHeight / 8)
            image.draw(at: imagePoint)
        }
        
        let attribs = [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 20),
            NSAttributedString.Key.foregroundColor: UIColor.white]
        
        let textSize = text.size(withAttributes: attribs)
        
        let textPoint = CGPoint(
            x: center.x - round(textSize.width / 2),
            y: center.y - round(textSize.height / 2) + boxHeight / 4)
        
        text.draw(at: textPoint, withAttributes: attribs)
    }
    
    //show the animation
    func show(animated: Bool) {
        if animated {
            alpha = 0
            transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
            
            //configure rotation
            let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
            rotationAnimation.fromValue = 0.0
            rotationAnimation.toValue = Float.pi * 2.0
            rotationAnimation.duration = 0.5
            rotationAnimation.repeatCount = 1
            layer.add(rotationAnimation, forKey: "rotationAnimationKey")
            
            //animate
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.2, options: [], animations: {
                self.alpha = 1
                self.transform = CGAffineTransform.identity
            })
        }
    }
    
    //hide the hud
    func hide() {
        superview?.isUserInteractionEnabled = true
        removeFromSuperview()
    }
}
