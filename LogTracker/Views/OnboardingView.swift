import SwiftUI

public struct OnboardingView: View {
    @ObservedObject var viewModel: AppViewModel
    
    @State private var baselineAverage: Double = 4.5
    @State private var isCustomInput = false
    @State private var customInputText = "4.5"
    
    private let presets: [Double] = [3.5, 4.0, 4.2, 4.5, 5.0]
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // Header Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 90, height: 90)
                    
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.blue)
                }
                
                // Title & Subtitle
                VStack(spacing: 8) {
                    Text("Welcome to Office Hours")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    
                    Text("Set your existing 8-week office presence so you don't start at 0.0 hrs/day.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                // Average Configuration Card
                VStack(spacing: 18) {
                    Text("CURRENT 8-WEEK TRAILING AVERAGE")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .tracking(1)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(String(format: "%.1f", baselineAverage))
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(baselineColor)
                        
                        Text("hrs / day")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Stepper Controls
                    HStack(spacing: 20) {
                        Button {
                            adjustAverage(by: -0.1)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 34))
                                .foregroundColor(.secondary)
                        }
                        
                        // Quick Presets
                        HStack(spacing: 8) {
                            ForEach(presets, id: \.self) { preset in
                                Button {
                                    withAnimation {
                                        baselineAverage = preset
                                    }
                                } label: {
                                    Text(String(format: "%.1fh", preset))
                                        .font(.subheadline.bold())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(abs(baselineAverage - preset) < 0.05 ? Color.blue : Color(.systemGray5))
                                        .foregroundColor(abs(baselineAverage - preset) < 0.05 ? .white : .primary)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        
                        Button {
                            adjustAverage(by: 0.1)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 34))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .foregroundColor(.orange)
                        Text("We will backfill your past 40 workdays (Mon–Fri) matching this average so your 8-week charts and notifications start up to date.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(20)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
                .padding(.horizontal)
                
                Spacer()
                
                // Bottom Buttons
                VStack(spacing: 12) {
                    Button {
                        viewModel.completeOnboarding(initialAverage: baselineAverage)
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Set Baseline & Fill Past 8 Weeks")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .font(.headline)
                    }
                    
                    Button {
                        viewModel.completeOnboarding(initialAverage: nil)
                    } label: {
                        Text("Skip and Start from 0.0 hrs")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
    }
    
    private var baselineColor: Color {
        if baselineAverage >= 4.5 {
            return .green
        } else if baselineAverage >= 4.0 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func adjustAverage(by amount: Double) {
        withAnimation {
            let newVal = round((baselineAverage + amount) * 10) / 10.0
            baselineAverage = max(1.0, min(12.0, newVal))
        }
    }
}
