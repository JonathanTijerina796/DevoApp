import SwiftUI

// MARK: - Message Composer View
// Vista para escribir/editar mensajes del devocional

struct MessageComposerView: View {
    let dayNumber: Int
    let instruction: String
    let existingMessage: DevotionalMessageEntity?
    let onSend: (String) async -> Bool
    
    @State private var content: String = ""
    @State private var isLoading = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Instrucción del día o tema libre
                if instruction == NSLocalizedString("free_topic_instruction", comment: "") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("free_topic", comment: ""))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.accentBrand)
                        
                        Text(NSLocalizedString("free_topic_description", comment: ""))
                            .font(.system(size: 14))
                            .foregroundStyle(Color.primaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.accentBrand.opacity(0.1))
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("today_instruction", comment: ""))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.secondaryText)
                        
                        Text(instruction)
                            .font(.system(size: 16))
                            .foregroundStyle(Color.primaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.gray.opacity(0.1))
                }
                
                // Campo de texto
                TextEditor(text: $content)
                    .frame(minHeight: 200)
                    .padding(12)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding()
                
                Spacer()
                
                // Botón enviar/actualizar
                Button {
                    Task {
                        isLoading = true
                        let success = await onSend(content)
                        isLoading = false
                        
                        if success {
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(existingMessage != nil ? NSLocalizedString("update", comment: "") : NSLocalizedString("send", comment: ""))
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(content.isEmpty ? Color.gray : Color.accentBrand)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(content.isEmpty || isLoading)
                .padding()
            }
            .background(Color.screenBG.ignoresSafeArea())
            .navigationTitle(dayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("cancel", comment: "")) {
                        dismiss()
                    }
                    .foregroundStyle(Color.accentBrand)
                }
            }
            .onAppear {
                if let existing = existingMessage {
                    content = existing.content
                }
            }
        }
    }
    
    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: Date())
    }
}
