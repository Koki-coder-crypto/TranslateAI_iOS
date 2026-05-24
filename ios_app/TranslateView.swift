import SwiftUI
import PhotosUI

struct TranslateView: View {
    @EnvironmentObject var store: StoreManager
    @ObservedObject var translationStore: TranslationStore
    @State private var showCamera = false
    @State private var showImagePicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var currentTranslation: Translation?
    @State private var isTranslating = false
    @State private var errorMessage: String?
    @State private var showPaywall = false
    @State private var showResult = false
    @State private var targetLanguage: Language = .defaultTarget
    @State private var showLanguagePicker = false
    @State private var shimmerOffset: CGFloat = -200
    @State private var appeared = false
    @State private var captureAreaScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.appBG.ignoresSafeArea()
            backgroundGlow

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    headerSection
                    captureArea
                    languageSelector
                    if isTranslating { shimmerTranslating }
                    if let t = currentTranslation, showResult { resultSection(t) }
                    if let err = errorMessage { errorSection(err) }
                    Spacer(minLength: 100)
                }
                .padding(.top, 20)
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView { img in showCamera = false; Task { await translate(image: img) } }
        }
        .photosPicker(isPresented: $showImagePicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    await translate(image: img)
                }
            }
        }
        .sheet(isPresented: $showLanguagePicker) { languagePickerSheet }
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(store) }
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true } }
    }

    private var headerSection: some View {
        VStack(spacing: 6) {
            Text("TranslateAI")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.white, Color(hex: "B0BDD4")], startPoint: .top, endPoint: .bottom))
            Text("Snap. Translate. Understand.")
                .font(.system(size: 15)).foregroundStyle(Color.appMuted)
        }
    }

    private var captureArea: some View {
        VStack(spacing: 16) {
            // Main camera area
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.appSurface)
                    .frame(height: 220)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.appBorder, lineWidth: 1))

                if let img = capturedImage {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.black.opacity(0.3))
                        )
                        .overlay(
                            VStack {
                                Spacer()
                                HStack {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("Tap to retake")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                .padding(14)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(.bottom, 16)
                            }
                        )
                } else {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.appAccent.opacity(0.12))
                                .frame(width: 72, height: 72)
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(Color.appAccent)
                                .scaleEffect(appeared ? 1.0 : 0.8)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.2), value: appeared)
                        }
                        Text("Tap to capture text")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.appMuted)
                    }
                }
            }
            .scaleEffect(captureAreaScale)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: captureAreaScale)
            .onTapGesture {
                captureAreaScale = 0.97
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { captureAreaScale = 1.0 }
                Haptics.impact(.medium)
                checkAndShowCamera()
            }
            .padding(.horizontal, 20)

            // Buttons
            HStack(spacing: 12) {
                Button { Haptics.impact(.medium); checkAndShowCamera() } label: {
                    Label("Camera", systemImage: "camera.fill")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(GradientButtonStyle())

                Button { Haptics.impact(.light); showImagePicker = true } label: {
                    Label("Library", systemImage: "photo.on.rectangle")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
        }
    }

    private var languageSelector: some View {
        HStack(spacing: 16) {
            // Source (auto)
            HStack(spacing: 8) {
                Text("🔍").font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text("From").font(.system(size: 11)).foregroundStyle(Color.appMuted)
                    Text("Auto Detect").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                }
            }
            .padding(14)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 1))

            // Arrow
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appAccent)

            // Target
            Button { Haptics.impact(.light); showLanguagePicker = true } label: {
                HStack(spacing: 8) {
                    Text(targetLanguage.flag).font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("To").font(.system(size: 11)).foregroundStyle(Color.appMuted)
                        Text(targetLanguage.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "chevron.down").font(.system(size: 12)).foregroundStyle(Color.appAccent)
                }
                .padding(14)
                .background(Color.appAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appAccent.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    private var shimmerTranslating: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ProgressView().tint(Color.appAccent)
                Text("Translating...")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.appMuted)
            }

            // Shimmer lines
            VStack(spacing: 8) {
                ForEach(0..<3) { i in
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                LinearGradient(
                                    colors: [.clear, Color.appAccent.opacity(0.3), .clear],
                                    startPoint: .leading, endPoint: .trailing
                                )
                                .offset(x: shimmerOffset)
                                .frame(width: geo.size.width * 0.4)
                                .animation(.linear(duration: 1.2).repeatForever(autoreverses: false).delay(Double(i) * 0.2), value: shimmerOffset)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .frame(height: 14)
                    .frame(maxWidth: i == 2 ? 180 : .infinity)
                }
            }
            .padding(.top, 4)
        }
        .padding(20)
        .glassSurface(cornerRadius: 20)
        .padding(.horizontal, 20)
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                shimmerOffset = 200
            }
        }
    }

    private func resultSection(_ t: Translation) -> some View {
        VStack(spacing: 16) {
            // Original
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Original · \(t.sourceLanguage)", systemImage: "doc.text")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.appMuted)
                    Spacer()
                    Button {
                        Haptics.impact(.light)
                        UIPasteboard.general.string = t.originalText
                    } label: {
                        Image(systemName: "doc.on.doc").font(.system(size: 13)).foregroundStyle(Color.appMuted)
                    }
                }
                Text(t.originalText)
                    .font(.system(size: 14)).foregroundStyle(Color(white: 0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16).glassSurface(cornerRadius: 18)

            // Translation
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(t.targetLanguage, systemImage: "globe")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.appAccent)
                    Spacer()
                    Button {
                        Haptics.impact(.light)
                        UIPasteboard.general.string = t.translatedText
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.appAccent)
                    }
                }
                Text(t.translatedText)
                    .font(.system(size: 16, weight: .medium)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(Color.appAccent.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appAccent.opacity(0.25), lineWidth: 1))

            // New translation button
            Button {
                Haptics.impact(.medium)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    currentTranslation = nil; capturedImage = nil; showResult = false; errorMessage = nil
                }
            } label: {
                Label("Translate Another", systemImage: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(GradientButtonStyle())
        }
        .padding(.horizontal, 20)
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }

    private func errorSection(_ err: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color(hex: "F87171"))
            Text(err).font(.system(size: 14)).foregroundStyle(Color(hex: "F87171"))
        }
        .padding(16).glassSurface(cornerRadius: 16).padding(.horizontal, 20)
    }

    private var backgroundGlow: some View {
        ZStack {
            Ellipse().fill(Color.appAccent.opacity(0.08)).frame(width: 350, height: 280).blur(radius: 80).offset(x: 60, y: -200)
            Ellipse().fill(Color(hex: "F87171").opacity(0.04)).frame(width: 280, height: 220).blur(radius: 60).offset(x: -80, y: 100)
        }
        .ignoresSafeArea().allowsHitTesting(false)
    }

    private var languagePickerSheet: some View {
        NavigationStack {
            ZStack {
                Color.appBG.ignoresSafeArea()
                List {
                    ForEach(Language.all.filter { $0.id != "auto" }) { lang in
                        Button {
                            Haptics.selection()
                            withAnimation { targetLanguage = lang }
                            showLanguagePicker = false
                        } label: {
                            HStack(spacing: 12) {
                                Text(lang.flag).font(.system(size: 24))
                                Text(lang.name).font(.system(size: 16, weight: .medium)).foregroundStyle(.white)
                                Spacer()
                                if targetLanguage.id == lang.id {
                                    Image(systemName: "checkmark").foregroundStyle(Color.appAccent)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .listRowBackground(Color.appSurface)
                    }
                }
                .listStyle(.plain)
                .background(Color.appBG)
            }
            .navigationTitle("Translate To")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showLanguagePicker = false }.foregroundStyle(Color.appAccent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func checkAndShowCamera() {
        if !store.isPro {
            let uses = UserDefaults.standard.integer(forKey: "translate_uses")
            if uses >= StoreManager.freeUsesPerMonth { showPaywall = true; return }
        }
        showCamera = true
    }

    private func translate(image: UIImage) async {
        capturedImage = image; isTranslating = true; errorMessage = nil; showResult = false; currentTranslation = nil
        Haptics.impact(.medium)

        do {
            let result = try await TranslateAIService.shared.translate(image: image, targetLanguage: targetLanguage)
            let uses = UserDefaults.standard.integer(forKey: "translate_uses")
            UserDefaults.standard.set(uses + 1, forKey: "translate_uses")

            let translation = Translation(
                originalText: result.originalText,
                translatedText: result.translatedText,
                sourceLanguage: result.detectedLanguage,
                targetLanguage: targetLanguage.name,
                translatedAt: Date()
            )
            translationStore.add(translation)

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                currentTranslation = translation; isTranslating = false; showResult = true
            }
            Haptics.notification(.success)
        } catch {
            withAnimation { isTranslating = false }
            errorMessage = error.localizedDescription
            Haptics.notification(.error)
        }
    }
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController(); p.sourceType = .camera; p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { onCapture(img) }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }
    }
}
