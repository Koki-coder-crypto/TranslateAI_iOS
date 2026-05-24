import SwiftUI

struct HistoryView: View {
    @ObservedObject var translationStore: TranslationStore
    @State private var appeared = false

    private let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short; return f
    }()

    var body: some View {
        ZStack {
            Color.appBG.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("History").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                    Text("\(translationStore.translations.count)").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.appMuted)
                        .padding(.horizontal, 12).padding(.vertical, 6).background(Color.appSurface, in: Capsule())
                }
                .padding(.horizontal, 20).padding(.top, 60).padding(.bottom, 20)

                if translationStore.translations.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        ZStack {
                            Circle().fill(Color.appAccent.opacity(0.08)).frame(width: 100, height: 100)
                            Image(systemName: "clock.arrow.circlepath").font(.system(size: 40)).foregroundStyle(Color.appAccent.opacity(0.5))
                        }
                        Text("No translations yet").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                        Text("Translate your first text and it will appear here.").font(.system(size: 14)).foregroundStyle(Color.appMuted).multilineTextAlignment(.center)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(Array(translationStore.translations.enumerated()), id: \.element.id) { i, t in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(t.sourceLanguage).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.appMuted)
                                        .padding(.horizontal, 8).padding(.vertical, 3).background(Color.appSurface, in: Capsule())
                                    Image(systemName: "arrow.right").font(.system(size: 10)).foregroundStyle(Color.appMuted)
                                    Text(t.targetLanguage).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.appAccent)
                                        .padding(.horizontal, 8).padding(.vertical, 3).background(Color.appAccent.opacity(0.1), in: Capsule())
                                    Spacer()
                                    Text(fmt.string(from: t.translatedAt)).font(.system(size: 11)).foregroundStyle(Color.appMuted)
                                }
                                Text(t.originalText).font(.system(size: 13)).foregroundStyle(Color(white: 0.7)).lineLimit(1)
                                Text(t.translatedText).font(.system(size: 14, weight: .medium)).foregroundStyle(.white).lineLimit(2)
                            }
                            .padding(14).glassSurface(cornerRadius: 16)
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                            .opacity(appeared ? 1 : 0).offset(x: appeared ? 0 : 20)
                            .animation(.easeOut(duration: 0.35).delay(Double(i) * 0.05), value: appeared)
                        }
                        .onDelete(perform: translationStore.delete)
                    }
                    .listStyle(.plain).background(Color.clear)
                    .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 82) }
                }
            }
        }
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true } }
    }
}
