import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Fondo blanco
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Logo principal
                Image("DevoLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .shadow(color: .gray.opacity(0.3), radius: 15, x: 0, y: 5)
                

            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        print("Starting splash animation")
        
        // Animación del logo
        withAnimation(.easeOut(duration: 2.0)) {
            scale = 1.0
            opacity = 1.0
        }
        
        // Activar el indicador de carga después de un momento
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🔄 Showing loading indicator")
            withAnimation(.easeInOut(duration: 0.3)) {
                isAnimating = true
            }
        }
        
        // Completar el splash después de 2 segundos (reducido para test)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("🏁 Finishing splash, calling onComplete")
            onComplete()
        }
    }
}

#Preview {
    SplashView {
        print("Splash completed")
    }
}
