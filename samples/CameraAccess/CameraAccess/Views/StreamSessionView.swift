/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// StreamSessionView.swift
//
//

import MWDATCore
import SwiftUI
import UIKit

struct StreamSessionView: View {
  let wearables: WearablesInterface
  @ObservedObject private var wearablesViewModel: WearablesViewModel
  @StateObject private var viewModel: StreamSessionViewModel
  @StateObject private var geminiVM = GeminiSessionViewModel()
  @State private var hasAutoStartedGlasses = false

  init(wearables: WearablesInterface, wearablesVM: WearablesViewModel) {
    self.wearables = wearables
    self.wearablesViewModel = wearablesVM
    self._viewModel = StateObject(wrappedValue: StreamSessionViewModel(wearables: wearables))
  }

  var body: some View {
    ZStack {
      if viewModel.isStreaming {
        // Full-screen video view with streaming controls
        StreamView(viewModel: viewModel, wearablesVM: wearablesViewModel, geminiVM: geminiVM)
      } else if wearablesViewModel.skipToIPhoneMode {
        // Brief loading state while iPhone camera starts
        CameraLoadingView(isGlassesMode: false)
      } else if !hasAutoStartedGlasses {
        // Glasses mode: show loading while waiting for device and auto-connecting
        CameraLoadingView(isGlassesMode: true)
      } else {
        // Fallback after auto-start — show branded loading while reconnecting
        CameraLoadingView(isGlassesMode: true)
      }
    }
    .task {
      viewModel.geminiSessionVM = geminiVM
      geminiVM.streamingMode = viewModel.streamingMode
      if wearablesViewModel.skipToIPhoneMode && !viewModel.isStreaming {
        await viewModel.handleStartIPhone()
      } else if !wearablesViewModel.skipToIPhoneMode && !viewModel.isStreaming && viewModel.hasActiveDevice {
        // Device already available on appear — auto-start glasses
        hasAutoStartedGlasses = true
        await viewModel.handleStartStreaming()
      }
    }
    .onChange(of: viewModel.hasActiveDevice) { hasDevice in
      // Device just became available — auto-start glasses streaming
      if hasDevice && !viewModel.isStreaming && !wearablesViewModel.skipToIPhoneMode && !hasAutoStartedGlasses {
        hasAutoStartedGlasses = true
        Task {
          await viewModel.handleStartStreaming()
        }
      }
    }
    .onChange(of: viewModel.streamingMode) { newMode in
      geminiVM.streamingMode = newMode
    }
    .onChange(of: viewModel.streamingStatus) { newStatus in
      if newStatus == .stopped {
        // Return to home screen when streaming stops (both iPhone and glasses)
        if wearablesViewModel.skipToIPhoneMode {
          wearablesViewModel.skipToIPhoneMode = false
        } else {
          wearablesViewModel.showGlassesSession = false
        }
      }
    }
    .onAppear {
      UIApplication.shared.isIdleTimerDisabled = true
    }
    .onDisappear {
      UIApplication.shared.isIdleTimerDisabled = false
    }
    .alert("Error", isPresented: $viewModel.showError) {
      Button("OK") {
        viewModel.dismissError()
      }
    } message: {
      Text(viewModel.errorMessage)
    }
  }
}

struct CameraLoadingView: View {
  var isGlassesMode: Bool = false
  @State private var dotCount = 0
  private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

  var body: some View {
    ZStack {
      if isGlassesMode {
        Color(red: 0.0, green: 0.40, blue: 1.0).edgesIgnoringSafeArea(.all)
      } else {
        Color.black.edgesIgnoringSafeArea(.all)
      }

      VStack(spacing: 16) {
        if isGlassesMode {
          Image("Paramount Logo v2")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 120)
        }

        ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: .white))
          .scaleEffect(1.2)

        Text(isGlassesMode ? "Connecting to glasses" + String(repeating: ".", count: dotCount) : "Opening Camera" + String(repeating: ".", count: dotCount))
          .font(.system(size: 18, weight: .medium))
          .foregroundColor(.white)
          .frame(width: 260, alignment: .center)
      }
    }
    .onReceive(timer) { _ in
      dotCount = (dotCount % 3) + 1
    }
  }
}
