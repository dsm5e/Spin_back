//
//  ScanerView.swift
//  Spin
//
//  Created by Golyakovph on 24.04.2023.
//

import SwiftUI
import AVKit

struct ScanerView: View {
    
    // QR Scanner Properties
    @State private var isScanning: Bool = false
    @State private var session: AVCaptureSession = .init()
    @State private var cameraPermission: ScanerCameraPermission = .idle
    // QR Scanner AV Output
    @State private var qrOutput: AVCaptureMetadataOutput = .init()
    // Error Properties
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    // Camera QR delegate
    @StateObject private var qrDelegate = QRScannerDelegate()
    @StateObject private var viewModel = PriemkiVM()
    
    @State private var scannedCode: String = ""
    
    var body: some View {
        VStack(spacing: 8) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.accentColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Наведите на штрихкод")
                .font(.title3)
                .foregroundColor(.accentColor)
                .padding(.top, 20)
            Text("cканирование начнется автоматически")
                .font(.callout)
                .foregroundColor(.secondary)
            
            Spacer(minLength: 0)
            
            ///scanner
            
            GeometryReader {
                let size = $0.size
                
                ZStack {
                    CameraView(frameSize: CGSize(width: size.width, height: size.width), session: $session)
                        .scaleEffect(0.97)
                    
                    ForEach(0...4, id: \.self) { index in
                        let rotation = Double(index) * 90
                        
                        RoundedRectangle(cornerRadius: 2, style: .circular)
                            .trim(from: 0.61, to: 0.64)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                            .rotationEffect(.degrees(rotation))
                    }
                    
                }
                // Square shape
                .frame(width: size.width, height: size.width)
                // Scanner animation
                .overlay(alignment: .top, content: {
                    Rectangle()
                        .fill(Color.gray)
                        .frame(height: 3)
                        .shadow(color: .secondary, radius: 8, x: 0, y: isScanning ?  15 : -15)
                        .offset(y: isScanning ? size.width : 0)
                })
                // To make center square alignment
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 45)
            
            Spacer(minLength: 15)
            
            Text("Code is: \(scannedCode)")
            
            Spacer(minLength: 45)
        }
        .navigationBarBackButtonHidden()
        .padding(15)
        /// Cheking Camera Permission, when the View  is Visiblle
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                checkCameraPermission()
            }
        }
        .alert(errorMessage, isPresented: $showError) {
            if cameraPermission == .denided {
                Button("Настройки") {
                    let settingsString = UIApplication.openSettingsURLString
                    if let settingsURL = URL(string: settingsString) {
                        openURL(settingsURL)
                    }
                }
                Button("Отмена", role: .cancel) {
                }
            }
        }
        .onChange(of: qrDelegate.scannedCode) { newValue in
            if let code = newValue {
                viewModel.get1cItem(id: code)
                // TODO: отобразить загрузку
                scannedCode = code
                deActivatinScannerAnimation()
            }
        }
        .fullScreenCover(item: $viewModel.item1C, content: { item in
            ScannedItemView(scannedItemInfo: item)
        })
    }
    
    func reactivateScanner() {
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    /// Activating scanner animation method
    func activatinScannerAnimation() {
        withAnimation(.easeInOut(duration: 0.85).delay(0.1).repeatForever(autoreverses: true)) {
        }
    }
    
    /// De-Activating scanner animation method
    func deActivatinScannerAnimation() {
        withAnimation(.easeInOut(duration: 0.85)) {
        }
        DispatchQueue.global(qos: .background).async {
            session.stopRunning()
        }
    }
    
    /// Checking camera permission
    func checkCameraPermission() {
        Task {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                cameraPermission = .approved
                if session.inputs.isEmpty {
                    setupCamera()
                } else {
                    session.startRunning()
                }
            case .notDetermined:
                if await AVCaptureDevice.requestAccess(for: .video) {
                    cameraPermission = .approved
                    setupCamera()
                } else {
                    cameraPermission = .denided
                    presentError("Предоставьте доступ к камере для сканирования штрихкода")
                }
            case .denied, .restricted:
                cameraPermission = .denided
                presentError("Предоставьте доступ к камере для сканирования штрихкода")
            default: break
            }
        }
    }
    
    /// Setting Up Camera
    func setupCamera() {
        do {
            guard let device = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first else {
                presentError("UNKNOW DEVICE ERROR")
                return
            }
            
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input), session.canAddOutput(qrOutput) else {
                presentError("UNKNOWN INPUT/OUTPUT ERROR")
                return
            }
            
            // Adding input and output to Camera Session
            session.beginConfiguration()
            session.addInput(input)
            session.addOutput(qrOutput)
            /// Setting output config to read QR
            qrOutput.metadataObjectTypes = [.qr, .code128, .aztec, .codabar, .code39, .code39Mod43, .code93, .dataMatrix, .ean13, .ean8, .microPDF417, .pdf417]
            /// Adding Delegate to Retrieve  the Fetched Qr from Camera
            qrOutput.setMetadataObjectsDelegate(qrDelegate, queue: .main)
            session.commitConfiguration()
            /// Session must be started on Background
            DispatchQueue.global(qos: .background).async {
                session.startRunning()
            }
            activatinScannerAnimation()
        } catch {
            presentError(error.localizedDescription)
        }
    }
    
    /// Presentin Error
    func presentError(_ message: String) {
        errorMessage = message
        showError.toggle()
    }
}

struct ScanerView_Previews: PreviewProvider {
    static var previews: some View {
        ScanerView()
    }
}
