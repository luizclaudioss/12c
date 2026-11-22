# HP 12C — Calculadora Financeira para macOS

Simulador nativo para macOS da clássica calculadora financeira **HP 12C** em Swift/SwiftUI, com visual fiel (layout horizontal, teclas `f` dourada e `g` azul, display LCD de 7 segmentos com anunciadores), lógica RPN completa, funções financeiras, estatística, calendário, modo de programação (até 99 linhas) e memória contínua persistida no sistema.

## Como compilar e executar

### Requisitos
- macOS 14+ com Xcode Command Line Tools (`swift` 6 / SwiftPM).

### Executar diretamente via SwiftPM
```bash
swift run HP12C
```

### Gerar o pacote `.app` (`build/HP12C.app`)
```bash
./scripts/make_app.sh && open build/HP12C.app
```

### Executar a suíte de testes
```bash
swift test
```

## Recursos implementados

- **Pilha RPN completa**: `X, Y, Z, T`, `LSTx`, `ENTER`, `R↓`, `x≷y`, `CLx`, `CHS`, `EEX`.
- **Matemática e porcentagens**: `+`, `−`, `×`, `÷`, `yˣ`, `1/x`, `√x`, `eˣ`, `LN`, `FRAC`, `INTG`, `x²`, `n!`, `%`, `Δ%`, `%T`, `RND`.
- **Display LCD fiel**: modos `FIX 0–9` e `SCI`, notação científica automática em overflow/underflow, pisca em overflow (`9.999999 99`), separador US/europeu (`ON + .`), anunciadores `f`, `g`, `BEGIN`, `D.MY`, `C` e `PRGM`, e visualização de mantissa (`f CLEAR PREFIX`).
- **Financeiro completo**:
  - **TVM** (`n, i, PV, PMT, FV`) com modos `BEG`/`END`, períodos fracionários com juros simples ou compostos (`STO EEX` / `C`), `12×` e `12÷`.
  - **Amortização e juros**: `AMORT` (com arredondamento pelo modo de exibição) e `INT` (bases 360 e 365).
  - **Fluxo de caixa**: `CF0`, `CFj`, `Nj`, `RCL g CFj`, `RCL g Nj`, `NPV`, `IRR` e `RCL g R/S` (IRR com estimativa inicial em `X`).
  - **Títulos (Bonds)**: `PRICE` e `YTM` (base actual/actual semestral, resgate 100).
  - **Depreciação**: `SL`, `SOYD` e `DB`.
- **Calendário e estatística**:
  - Datas `M.DY` e `D.MY` (15/10/1582 a 25/11/4046), `DATE` (exibe dia da semana 1–7) e `ΔDYS` (dias reais e 30/360).
  - `Σ+`, `Σ−`, média (`x̄`), desvio padrão (`s`), média ponderada (`x̄w`) e regressão linear (`ŷ,r` e `x̂,r`).
- **Programação e memória**:
  - Até 99 linhas (`f P/R`), compartilhamento dinâmico com registradores (`R0..R9`, `R.0..R.9`, `g MEM`).
  - `STO`/`RCL` direto e aritmética de registrador (`STO +/−×÷ 0..4`).
  - Execução (`R/S`), pausa (`PSE`, 1 s), passo a passo (`SST`, `BST`), desvios (`GTO nn`, `GTO . nn`) e condicionais (`x≤y`, `x=0`).
- **Memória contínua**: salva automaticamente em `~/Library/Application Support/HP12C/state.json` a cada operação e ao encerrar o app.

## Atalhos de teclado

| Tecla | Função na HP 12C |
|---|---|
| `0`–`9` | Dígitos `0`–`9` |
| `.` ou `,` | Ponto decimal (`·`) |
| `+`, `-`, `*`, `/` | Operadores `+`, `−`, `×`, `÷` |
| `Return` / `Enter` | `ENTER` |
| `Delete` / `Backspace` | Apaga último dígito digitado (ou `CLx`) |
| `Esc` | Cancela prefixo (`f`, `g`, `STO`, `RCL`) / limpa erro |
| `f` | Prefixo dourado `f` |
| `g` | Prefixo azul `g` |
| `s` | `STO` |
| `r` | `RCL` |
| `n`, `i`, `p`, `m`, `v` | `n`, `i`, `PV`, `PMT`, `FV` |
| `c` | `CHS` |
| `e` | `EEX` |
| `x` | `x≷y` |
| `d` | `R↓` |
| `Espaço` | `R/S` |
| `o` | `ON` |
| `%` | `%` |
| `^` | `yˣ` |
| `⌘C` / `⌘V` | Copiar `X` / Colar número em `X` |

## Diferenças conhecidas em relação ao aparelho físico

- **Precisão numérica**: cálculos internos utilizam `Double` IEEE 754 (com normalização para 10 dígitos significativos após cada operação e arredondamento decimal em `RND`/`AMORT`), enquanto a HP 12C original utiliza aritmética BCD de 10 dígitos.
- **Velocidade de execução**: programas rodam na velocidade da CPU do Mac (exceto `PSE`, que mantém a pausa de 1 segundo), muito mais rápido que o hardware original.
- **Autoteste de fábrica**: sequências de diagnóstico de teclado/LCD (`ON + ×`, `ON + ÷`) não estão implementadas; estão disponíveis `ON + .` (separador europeu) e `ON + −` (reset da memória contínua com `Pr Error`), também acessíveis pelo menu **Calculadora**.
