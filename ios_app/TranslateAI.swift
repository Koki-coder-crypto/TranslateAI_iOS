import Foundation
import UIKit

actor TranslateAIService {
    static let shared = TranslateAIService()
    private let apiKey = Bundle.main.infoDictionary?["ANTHROPIC_API_KEY"] as? String ?? ""

    struct TranslateResult: Codable {
        let detectedLanguage: String
        let translatedText: String
        let originalText: String
    }

    func translate(image: UIImage, targetLanguage: Language) async throws -> TranslateResult {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { throw AIError.imageConversion }
        let base64 = imageData.base64EncodedString()

        let prompt = """
        Look at this image and extract all visible text. Then translate it to \(targetLanguage.name).
        Return ONLY valid JSON:
        {"detectedLanguage": "detected language name", "originalText": "all text found in the image", "translatedText": "complete translation to \(targetLanguage.name)"}
        If the image has no text, set originalText to "No text found" and translatedText to "No text found".
        """

        let body: [String: Any] = [
            "model": "claude-opus-4-5",
            "max_tokens": 2000,
            "messages": [["role": "user", "content": [
                ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": base64]],
                ["type": "text", "text": prompt]
            ]]]
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw AIError.apiError }

        struct AnthropicResponse: Codable {
            struct Content: Codable { let text: String }
            let content: [Content]
        }

        let resp = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        guard let text = resp.content.first?.text else { throw AIError.parseError }

        let jsonText = extractJSON(from: text)
        guard let jsonData = jsonText.data(using: .utf8),
              let result = try? JSONDecoder().decode(TranslateResult.self, from: jsonData)
        else { throw AIError.parseError }

        return result
    }

    func translateText(_ text: String, targetLanguage: Language) async throws -> String {
        let body: [String: Any] = [
            "model": "claude-opus-4-5",
            "max_tokens": 2000,
            "messages": [["role": "user", "content": "Translate the following text to \(targetLanguage.name). Return ONLY the translation, no explanations:\n\n\(text)"]]
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw AIError.apiError }

        struct AnthropicResponse: Codable {
            struct Content: Codable { let text: String }
            let content: [Content]
        }
        let resp = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        return resp.content.first?.text ?? ""
    }

    private func extractJSON(from text: String) -> String {
        if let start = text.range(of: "{"), let end = text.range(of: "}", options: .backwards) {
            return String(text[start.lowerBound...end.upperBound])
        }
        return text
    }

    enum AIError: LocalizedError {
        case imageConversion, apiError, parseError
        var errorDescription: String? {
            switch self {
            case .imageConversion: return "Could not process image"
            case .apiError: return "AI service unavailable"
            case .parseError: return "Could not parse translation"
            }
        }
    }
}
