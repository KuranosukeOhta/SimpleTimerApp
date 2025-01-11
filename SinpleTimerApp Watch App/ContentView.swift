//
//  ContentView.swift
//  SinpleTimerApp Watch App
//
//  Created by Kuranosuke Ohta on 2025/01/12.
//

import SwiftUI
import WatchKit

struct ContentView: View {
    @State private var selectedMinutes = 0 // 初期選択分を0分に設定
    @State private var selectedSeconds = 10 // 初期選択秒を10秒に設定
    @State private var timeRemaining = 10 // カウントダウンの初期値
    @State private var timer: Timer? // タイマーを保持するための変数
    @State private var hapticTimer: Timer? // 触覚フィードバック用のタイマー

    var body: some View {
        ScrollView { // VStackをScrollViewでラップしてスクロール可能にする
            VStack {
                HStack { // ピッカーを横に並べる
                    VStack {
                        Text("分")
                            .font(.caption)
                        Picker("編集中...", selection: $selectedMinutes) {
                            ForEach(0..<60) { minute in
                                Text("\(minute)")
                                    .tag(minute)
                                    .foregroundColor(selectedMinutes == minute ? .green : .white)
                                    .font(selectedMinutes == minute ? .title : .body)
                                    .animation(.easeInOut(duration: 0.1), value: selectedMinutes)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                    }

                    VStack {
                        Text("秒")
                            .font(.caption)
                        Picker("編集中...", selection: $selectedSeconds) {
                            ForEach(0..<60) { second in
                                Text("\(second)")
                                    .tag(second)
                                    .foregroundColor(selectedSeconds == second ? .green : .white)
                                    .font(selectedSeconds == second ? .title : .body)
                                    .animation(.easeInOut(duration: 0.1), value: selectedSeconds)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                    }
                }
                .onChange(of: selectedMinutes) { oldValue, newValue in 
                    updateTimeRemaining()
                }
                .onChange(of: selectedSeconds) { oldValue, newValue in 
                    updateTimeRemaining()
                }
                
                Text("残り時間: \(timeRemaining) 秒")
                    .font(.body)
                    .padding()

                Button(action: {
                    startCountdown()
                }) {
                    Text("タイマー開始")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BorderedButtonStyle(tint: .orange))
                
                // Haptics Previewボタンをコメントアウト
                //                Button("Haptics Preview", action: { hapticsPreview() })
                //                    .buttonStyle(BorderedButtonStyle())
            }
            .padding()
            .onAppear {
                startAppAlert()
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
    }

    func updateTimeRemaining() {
        // 分と秒を合計して残り時間を設定
        timeRemaining = selectedMinutes * 60 + selectedSeconds
    }

    func startCountdown() {
        timer?.invalidate() // 既存のタイマーを無効にする
        timeRemaining = selectedMinutes * 60 + selectedSeconds // カウントダウンをリセット
        
        // タイマー開始時の触覚フィードバック
        WKInterfaceDevice.current().play(.start)

        // 1秒ごとにカウントダウンを更新するタイマーを設定
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1 // 残り時間を1秒減らす
                // ピッカーの値をアニメーション付きで更新
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedMinutes = timeRemaining / 60
                    selectedSeconds = timeRemaining % 60
                }
            } else {
                timer?.invalidate() // 残り時間が0になったらタイマーを無効にする
                alertTimer() // タイマー終了時の処理を呼び出す
            }
        }
    }

    func alertTimer() {
        print("タイマーが終了しました！")
        
        // アラートを表示する
        if let rootController = WKExtension.shared().rootInterfaceController {
            // 既存の触覚フィードバックタイマーを停止
            hapticTimer?.invalidate()
            
            // 触覚フィードバックを開始
            hapticTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                WKInterfaceDevice.current().play(.failure)
            }
            
            rootController.presentAlert(withTitle: "タイマー終了", message: "タイマーが終了しました！", preferredStyle: .alert, actions: [
                WKAlertAction(title: "OK", style: .default, handler: { 
                    print("OKボタンが押されました！")
                    // OKボタンが押されたら触覚フィードバックを停止
                    self.hapticTimer?.invalidate()
                    self.hapticTimer = nil
                })
            ])
        }
    }
}

#Preview {
    ContentView()
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch Series 9"))
            
            ContentView()
                .previewDevice(PreviewDevice(rawValue: "Apple Watch Ultra"))
        }
    }
}

func startAppAlert() {
    print("アプリが起動しました！")
    //通知のハプティクスを再生
    WKInterfaceDevice.current().play(.directionUp)
}

// Haptics Preview関数をコメントアウト
//func hapticsPreview() {
//    print("触覚フィードバックの再生を開始します！")
//    
//    // すべての触覚フィードバックを順番に再生する
//    let hapticTypes: [WKHapticType] = [
//        .notification, // 通知
//        .directionUp,  // 上方向
//        .directionDown, // 下方向
//        .success,      // 成功
//        .failure,      // 失敗
//        .retry,        // 再試行
//        .start,        // 開始
//        .stop,         // 停止
//        .click         // クリック
//    ]
//    
//    for haptic in hapticTypes {
//        WKInterfaceDevice.current().play(haptic) // 触覚フィードバックを再生
//        Thread.sleep(forTimeInterval: 1) // 各フィードバックの間に1秒の間隔を空ける
//    }
//}

