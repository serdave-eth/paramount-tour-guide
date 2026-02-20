/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// HomeScreenView.swift
//
// Welcome screen that guides users through the DAT SDK registration process.
// This view is displayed when the app is not yet registered.
//

import MWDATCore
import SwiftUI

struct HomeScreenView: View {
  @ObservedObject var viewModel: WearablesViewModel
  @State private var showSettings = false

  private var glassesButtonLabel: String {
    if viewModel.registrationState == .registered {
      return "Experience the Lot"
    } else if viewModel.registrationState == .registering {
      return "Connecting..."
    } else {
      return "Connect my glasses"
    }
  }

  var body: some View {
    ZStack {
      Color(red: 0.0, green: 0.40, blue: 1.0).edgesIgnoringSafeArea(.all)

      VStack(spacing: 12) {
        HStack {
          Spacer()
          Button {
            showSettings = true
          } label: {
            Image(systemName: "gearshape")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .foregroundColor(.white)
              .frame(width: 24, height: 24)
          }
        }

        Spacer()

        Image("Paramount Logo v2")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 160)

        Text("Welcome to Paramount Lens. You are standing on one of the most storied creative campuses in the world. Through this experience, uncover the productions, talent, and moments that shaped cultural history right where they happened.")
          .font(.system(size: 18))
          .foregroundColor(.white)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 12)
          .padding(.top, 8)

        Spacer()

        VStack(spacing: 20) {
          if viewModel.registrationState != .registered {
            Text("You'll be redirected to the Meta AI app to confirm your connection.")
              .font(.system(size: 14))
              .foregroundColor(.white.opacity(0.7))
              .multilineTextAlignment(.center)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.horizontal, 12)
          }

          Button {
            if viewModel.registrationState == .registered {
              viewModel.showGlassesSession = true
            } else {
              viewModel.connectGlasses()
            }
          } label: {
            Text(glassesButtonLabel)
              .font(.system(size: 15, weight: .semibold))
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 56)
              .background(Color(red: 0.0, green: 0.12, blue: 0.36))
              .cornerRadius(30)
          }
          .disabled(viewModel.registrationState == .registering)
          .opacity(viewModel.registrationState == .registering ? 0.6 : 1.0)

          Button {
            viewModel.skipToIPhoneMode = true
          } label: {
            Text("Start on iPhone")
              .font(.system(size: 15, weight: .semibold))
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 56)
              .background(Color(red: 0.0, green: 0.12, blue: 0.36))
              .cornerRadius(30)
          }
        }
      }
      .padding(.all, 24)
    }
    .sheet(isPresented: $showSettings) {
      SettingsView(connectAction: {
        viewModel.connectGlasses()
      })
    }
  }

}
