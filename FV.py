import pandas as pd
import numpy_financial as npf
import numpy as np

# 1. 參數設定
# 注意：你題目中的 8% 和 10% 之間少了一個逗號，我推測是 8%, 10%
returns = [0.10, 0.12, -0.05, 0.08, 0.10, -0.25, 0.03, 0.20, 0.02, -0.10]
annual_investment = 10000
current_wealth = 0
matrix_data = []

# 2. 使用迴圈計算每年的財富累積
# 這裡假設「每年年初」投入 10,000 元，年底結算本利和
for i, r in enumerate(returns):
    # 當年財富 = (前一年年底財富 + 本年投入) * (1 + 當年報酬率)
    current_wealth = (current_wealth + annual_investment) * (1 + r)
    
    # 記錄每年數據，準備做成矩陣
    matrix_data.append([i + 1, f"{r*100}%", round(current_wealth, 2)])

# 3. 將結果寫成矩陣 (使用 Pandas DataFrame 呈現)
df = pd.DataFrame(matrix_data, columns=['年份 (Year)', '當年報酬率 (Return)', '年底財富 (Wealth)'])

# 4. 取得 10 年後總財富
final_wealth = current_wealth

# 5. 計算年化報酬率
# 5a. 定期定額的「投資人真實年化報酬率」 (使用 IRR 內部報酬率)
# 現金流：第 0~9 年初每年投入 -10,000，第 10 年底拿回 final_wealth
cash_flows = [-annual_investment] * 10 + [final_wealth]
portfolio_irr = npf.irr(cash_flows)

# 5b. SPY「資產本身」的幾何平均年化報酬率 (CAGR)
asset_cagr = np.prod([1 + r for r in returns]) ** (1 / len(returns)) - 1

# 印出結果
print("=== 每年財富累積矩陣 ===")
print(df.to_string(index=False))
print("\n=== 最終結果 ===")
print(f"10年後總投入成本: {annual_investment * 10:,.0f} 元")
print(f"10年後最終財富: {final_wealth:,.2f} 元")
print("-" * 30)
print(f"SPY 資產本身的年化報酬率: {asset_cagr:.2%}")
print(f"定期定額投資的年化報酬率 (IRR): {portfolio_irr:.2%}")