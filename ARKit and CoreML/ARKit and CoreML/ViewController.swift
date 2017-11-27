//
//  ViewController.swift
//  ARKit and CoreML
//
//  Created by weiguang on 2017/11/21.
//  Copyright © 2017年 weiguang. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    // 拿到模型
    var resentModel = Resnet50()
    // 点击之后的结果
    var hitTestResult: ARHitTestResult!
    
    //分析的结果
    var visionRequests = [VNRequest]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()

        // Set the scene to the view
        sceneView.scene = scene
        
        registerGestureRecognizers()
    }
    
    func registerGestureRecognizers() {
        let tapGes = UITapGestureRecognizer(target: self, action: #selector(tapped))
        self.sceneView.addGestureRecognizer(tapGes)
    }
    
    @objc func tapped(recognizer: UITapGestureRecognizer){
        //当前画面的 sceneView = 截图
        let sceneView = recognizer.view as! ARSCNView
        let touchLocation = self.sceneView.center
        
        guard let currentFrame = sceneView.session.currentFrame else { return } // 判别当前有像素
        let hitTestResults = sceneView.hitTest(touchLocation, types: .featurePoint) //识别物件的特征点
        if hitTestResults.isEmpty { return }
        
        //可能会因为手抖连续点击多次，只取第一次点击的结果
        guard let hitTestResult = hitTestResults.first else { return }
        
        self.hitTestResult = hitTestResult  //拿到点击结果
        
        // 拿到的图片转成像素，因为模型要输入的图片是pixelBuffer格式的
        let pixelBuffer = currentFrame.capturedImage
       
        performVisionRequest(pixelBuffer: pixelBuffer)
    }
    
    // 展示预测的结果
    func displayPredictions(text: String){
        let node = createText(text: text)
        
        // 把现实世界的坐标 转到手机对应的坐标，展示在屏幕中央
        node.position = SCNVector3(self.hitTestResult.worldTransform.columns.3.x,
                                   self.hitTestResult.worldTransform.columns.3.y,
                                   self.hitTestResult.worldTransform.columns.3.z)
        
        self.sceneView.scene.rootNode.addChildNode(node) // 把AR结果展示出来
    }
    
    // 制作结果的AR图标跟底座
    func createText(text: String) -> SCNNode {
        // 创建父节点
        let parentNode = SCNNode()
        
        //创建底座
        // 创建一个 1cm 的小球形状
        let sphere = SCNSphere(radius: 0.01)
        let sphereMaterial = SCNMaterial()
        // 设置小球为橘色
        sphereMaterial.diffuse.contents = UIColor.orange
        sphere.firstMaterial = sphereMaterial
        // 生成小球的节点
        let sphereNode = SCNNode(geometry: sphere)
        
        //生成AR文字形状
        let textGeo = SCNText(string: text, extrusionDepth: 0)
        // 设置文字的属性
        textGeo.alignmentMode = kCAAlignmentCenter
        textGeo.firstMaterial?.diffuse.contents = UIColor.orange
        textGeo.firstMaterial?.specular.contents = UIColor.white
        textGeo.firstMaterial?.isDoubleSided = true
        textGeo.font = UIFont(name: "Futura", size: 0.15)
        
        // 生成文字节点
        let textNode = SCNNode(geometry: textGeo)
        textNode.scale = SCNVector3Make(0.2, 0.2, 0.2)
        
        parentNode.addChildNode(sphereNode)
        parentNode.addChildNode(textNode)
        
        return parentNode
    }
    
    func performVisionRequest(pixelBuffer: CVPixelBuffer){
        // 请 ML Model 做事情
        let visionModel = try! VNCoreMLModel(for: self.resentModel.model)
        
        let request = VNCoreMLRequest(model: visionModel) { (request, error) in
            // TO DO
            if error != nil { return }
            
            guard let observations = request.results else { return } // 把结果拿出来
            
            // 把结果中的第一位拿出来进行分析，类似模型里面的黑盒子，用来处理
            let observation = observations.first as! VNClassificationObservation
            
            print("Name: \(observation.identifier) and confidence is \(observation.confidence)")
            
            // 把获取的结果展示出来，需要刷新UI，在主线程进行
            DispatchQueue.main.async {
                self.displayPredictions(text: observation.identifier)
            }
        }
        
        request.imageCropAndScaleOption = .centerCrop  //进行喂食
        
        self.visionRequests = [request] // 拿到结果
        
        // 将拿到的结果镜像
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .upMirrored, options: [:])
        
        // 处理所有的结果，可能时间比较长，需在异步中开启新线程执行
        DispatchQueue.global().async {
            try! imageRequestHandler.perform(self.visionRequests)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}
