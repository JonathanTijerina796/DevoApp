import SwiftUI

// MARK: - Devotional Chat View
// Vista de chat tipo WhatsApp para los mensajes del devocional

struct DevotionalChatView: View {
    let messages: [DevotionalMessageEntity]
    let currentUserId: String
    let onEditMessage: (DevotionalMessageEntity) -> Void
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(
                            message: message,
                            isCurrentUser: message.userId == currentUserId,
                            onEdit: {
                                onEditMessage(message)
                            }
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _, _ in
                if let lastMessage = messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: DevotionalMessageEntity
    let isCurrentUser: Bool
    let onEdit: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isCurrentUser {
                // Avatar del remitente (solo si no es el usuario actual)
                Circle()
                    .fill(avatarColor)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(String(message.userName.prefix(1)).uppercased())
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // Nombre del usuario (solo si no es el usuario actual)
                if !isCurrentUser {
                    Text(message.userName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.secondaryText)
                }
                
                // Contenido del mensaje
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(isCurrentUser ? .white : .primaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isCurrentUser ? Color.accentBrand : Color.gray.opacity(0.2))
                    )
                    .contextMenu {
                        if isCurrentUser {
                            Button {
                                onEdit()
                            } label: {
                                Label(NSLocalizedString("edit", comment: ""), systemImage: "pencil")
                            }
                        }
                    }
                
                // Indicador de editado y hora
                HStack(spacing: 4) {
                    if message.isEdited {
                        Text(NSLocalizedString("edited", comment: ""))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondaryText)
                    }
                    
                    Text(timeString(from: message.updatedAt))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: isCurrentUser ? .trailing : .leading)
            
            if isCurrentUser {
                Spacer()
            }
        }
    }
    
    private var avatarColor: Color {
        // Generar color basado en el nombre del usuario
        let colors: [Color] = [
            Color(red: 0.2, green: 0.4, blue: 0.8),
            Color(red: 0.8, green: 0.3, blue: 0.5),
            Color(red: 0.3, green: 0.6, blue: 0.4),
            Color(red: 0.9, green: 0.6, blue: 0.2),
            Color(red: 0.5, green: 0.3, blue: 0.7),
        ]
        let index = abs(message.userName.hashValue) % colors.count
        return colors[index]
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
