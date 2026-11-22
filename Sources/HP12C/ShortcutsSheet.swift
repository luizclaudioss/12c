import SwiftUI

struct ShortcutsSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let shortcuts: [(tecla: String, acao: String)] = [
        ("0 – 9", "Dígitos 0 a 9"),
        (". ou ,", "Ponto decimal (·)"),
        ("+  -  *  /", "Operadores +, −, ×, ÷"),
        ("Return / Enter", "ENTER"),
        ("Delete / Backspace", "Apaga último dígito (ou CLx)"),
        ("Esc", "Cancela prefixo (f, g, STO, RCL) / limpa erro"),
        ("f", "Prefixo dourado (f)"),
        ("g", "Prefixo azul (g)"),
        ("s", "STO"),
        ("r", "RCL"),
        ("n", "n (períodos)"),
        ("i", "i (taxa de juros)"),
        ("p", "PV (valor presente)"),
        ("m", "PMT (prestação)"),
        ("v", "FV (valor futuro)"),
        ("c", "CHS (trocar sinal)"),
        ("e", "EEX (expoente)"),
        ("x", "x≷y (trocar X e Y)"),
        ("d", "R↓ (rolar pilha)"),
        ("Espaço", "R/S (executar / parar programa)"),
        ("o", "ON (ligar / desligar)"),
        ("%", "% (porcentagem)"),
        ("^", "yˣ (potência)"),
        ("⌘C / ⌘V", "Copiar X / Colar número em X")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Atalhos de Teclado — HP 12C")
                    .font(.headline)
                Spacer()
                Button("Fechar") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.fixed(155), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 7) {
                    ForEach(shortcuts, id: \.tecla) { item in
                        Text(item.tecla)
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .foregroundColor(.accentColor)
                        Text(item.acao)
                            .font(.body)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(20)
        .frame(width: 460, height: 470)
    }
}
