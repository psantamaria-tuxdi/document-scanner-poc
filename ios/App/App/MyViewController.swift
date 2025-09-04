import UIKit
import Capacitor

class MyViewController: CAPBridgeViewController {
    override func capacitorDidLoad() {
        // Esto “activa” tu plugin dentro del bridge de Capacitor
        bridge?.registerPluginInstance(DocumentScannerIOS())
    }
}
