//
//  LunchingViewController.swift
//  FridgeHelper
//
//  Created by 林仲景 on 2023/7/18.
//

import UIKit

class LunchingViewController: UIViewController {
    var timer:Timer?
    
    //登入畫面的label點點個數
    var launchScreen:UIViewController?
    var dotNumbers = 0
    var countDown = 6{
        didSet{
            if countDown == -1{
                timer?.invalidate()
                UIView.animate(withDuration: 0.5) {
                    let controller = self.storyboard?.instantiateViewController(identifier: "NavigationController")
                    self.view.window?.rootViewController = controller
                }
            }
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //setlaunchScreenLabelAnimation()
        setlaunchScreenImageAnimation()
    }
    
    //動畫一：loading在跑
    private func setlaunchScreenLabelAnimation(){
        let launchStoryboard = UIStoryboard(name: "LaunchScreen", bundle: nil)
        launchScreen = launchStoryboard.instantiateInitialViewController()
        if let label = launchScreen?.view.viewWithTag(1) as? UILabel{
            view.addSubview(launchScreen!.view)
            //標籤的動畫
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: {[self] _ in
                countDown-=1
                dotNumbers+=1
                dotNumbers = dotNumbers % 4
                label.text = "Loading"+String(repeating: ".", count: dotNumbers)
            })
        }
    }
    
    //動畫二：冰箱轉圈圈
    private func setlaunchScreenImageAnimation(){
        let launchStoryboard = UIStoryboard(name: "LaunchScreen", bundle: nil)
        launchScreen = launchStoryboard.instantiateInitialViewController()
        view.addSubview(launchScreen!.view)
        if let label = launchScreen?.view.viewWithTag(1) as? UILabel,
           let imageView = launchScreen?.view.viewWithTag(2) as? UIImageView{
            
            UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 0, delay: 0, options: .allowAnimatedContent) {
                //這裡面沒有物件實質在做變化，是圖層在做變化，所以第一段動畫的時間不管設多少都沒有作用，會馬上跳到第二段動畫
                let rotationAnimate = CABasicAnimation(keyPath: "transform.rotation")
                rotationAnimate.fromValue = 0
                rotationAnimate.toValue = Double.pi*2
                rotationAnimate.duration = 0.8
                imageView.layer.add(rotationAnimate, forKey: nil)
                print("第一段動畫做完了")
                //imageView.transform的方法無法轉360度
                //imageView.transform = CGAffineTransform.identity.rotated(by: <#T##CGFloat#>)
            } completion: { _ in
                //元件的更動以動畫表示
                //因為馬上就會跳到第二段動畫，所以第二段動畫要先delay，等第一段的圖層動畫跑完才會剛好接上第二段的動畫
                UIViewPropertyAnimator.runningPropertyAnimator(withDuration: 1.0, delay: 0.8, options: .curveEaseInOut) {
                    label.alpha = 1
                    print("第二段動畫做完了")
                } completion: { _ in
                    //transition用在畫面轉場用, with參數表示container View
                    UIView.transition(with: self.view.window!, duration: 1, options: .transitionCrossDissolve, animations: {
                        let controller = self.storyboard?.instantiateViewController(identifier: "NavigationController")
                        //let oldState = UIView.areAnimationsEnabled
                        UIView.setAnimationsEnabled(false)
                        self.view.window?.rootViewController = controller
                        UIView.setAnimationsEnabled(true)
                        print("第三段動畫做完了")
                    }, completion: nil)
                    
                }
            }


        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
