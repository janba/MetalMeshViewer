//
//  GameViewController.swift
//  MetalMeshViewer
//
//  Created by Andreas Bærentzen on 06/11/2021.
//

import Cocoa
import MetalKit
import GameController

class CustomMTKView: MTKView  {
    var renderer: Renderer?

    required init(frame: NSRect, device: MTLDevice) {
        super.init(frame: frame, device: device)
        registerForDraggedTypes([ NSPasteboard.PasteboardType.fileURL ])
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteBoard = sender.draggingPasteboard
        if let urls = pasteBoard.readObjects(forClasses: [NSURL.self]) as? [URL]{
            if renderer!.load_mesh(asset_url: urls[0]) {
                NSDocumentController.shared.noteNewRecentDocumentURL(urls[0])
                
                // menu is a global variable, and apparently it is being shadowed below
                // by a local variable, so we write MetalMeshViewer.menu to make sure we
                // refer to the right one. MetalMeshViewer is the module, and it seems
                // that is the way to be explicit about globals in Swift.
                MetalMeshViewer.menu.redo_recent_menu()
                return true
            }
        }
        return false
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return NSDragOperation.copy
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let allow = true // check your types...
        return allow
    }
        
}

// Our macOS specific view controller
class AppViewController: NSViewController {

    var renderer: Renderer!
    var draw_wire = false
    var draw_flat = false
    
    override func loadView() {
        // Select the device to render with.  We choose the default device
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }
        self.view = CustomMTKView(frame: NSRect(x: 0, y: 0, width: 1200, height: 800), device: defaultDevice)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let mtkView = self.view as? CustomMTKView else {
            print("View attached to GameViewController is not an MTKView")
            return
        }
        guard let newRenderer = Renderer(metalKitView: mtkView) else {
            print("Renderer cannot be initialized")
            return
        }
        renderer = newRenderer
        mtkView.renderer = renderer
        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)
        mtkView.delegate = renderer
        
        /* Add detection of key presses. Note that we return nil below if we used
         the key, and otherwise we return the key event. This is because there is
         an annoying sound if the key is not used. However, the key may be used by
         another responder (e.g. if we press command-q to quit) so alway returning
         nil is a bad idea. */
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            if (self.parse_key(with: $0)) {
                return nil
            }
            return $0
        }

    }
    
    override func mouseDragged(with event: NSEvent) {
        renderer.rotate(delta_x: Float(event.deltaX), delta_y: Float(event.deltaY))
    }
    
    override func rightMouseDragged(with event: NSEvent) {
        renderer.pan(delta_x: Float(event.deltaX), delta_y: Float(event.deltaY))
    }
    
    override func scrollWheel(with event: NSEvent) {
        renderer.change_proximity(delta_prox: Float(event.scrollingDeltaY))
    }
    
    func load_file(url: URL) -> Bool {
        if renderer!.load_mesh(asset_url: url) {
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            
            // menu is a global variable, and apparently it is being shadowed below
            // by a local variable, so we write MetalMeshViewer.menu to make sure we
            // refer to the right one. MetalMeshViewer is the module, and it seems
            // that is the way to be explicit about globals in Swift.
            MetalMeshViewer.menu.redo_recent_menu()
            return true
        }
        return false
    }
    
    func parse_key(with event: NSEvent) -> Bool {
        switch event.keyCode {
        case 3:
            draw_flat = !draw_flat
            renderer.rebuild_pipeline(draw_wire: draw_wire, draw_flat: draw_flat)
            return true
        case 13:
            draw_wire = !draw_wire
            renderer.rebuild_pipeline(draw_wire: draw_wire, draw_flat: draw_flat)
            return true
        case 15:
            renderer.reset_trackball()
            return true
        case 7:
            renderer.set_up_axis(axis: 0)
            return true
        case 16:
            renderer.set_up_axis(axis: 1)
            return true
        case 6:
            renderer.set_up_axis(axis: 2)
            return true
        case 18...21:
            let mat_cap_idx = Int(event.keyCode-18)
            renderer.set_matcap(matcap_no: mat_cap_idx)
            return true
        default:
            break
        }
        return false
    }
}
