# 檔案名稱要叫app.py
# 先下載套件 pip install numpy-financial
# terminal下 streamlit run app.py 
import streamlit as st
import pandas as pd
import numpy as np

st.set_page_config(page_title="SPY 定期定額計算機", layout="wide")
st.markdown("<h3 style='text-align: center; margin-top: -30px;'>SPY 定期定額投資分析</h3>", unsafe_allow_html=True)

# ==========================================
# 側邊欄：參數設定
# ==========================================
st.sidebar.header("設定參數")
annual_investment = st.sidebar.number_input("每年定期定額 ($)", min_value=1000, value=10000, step=1000)
default_returns = "10, 12, -5, 8, 10, -25, 3, 20, 2, -10"
# 限制文字框的高度
returns_input = st.sidebar.text_area("各年度報酬率 (%)", value=default_returns, height=100)

# ==========================================
# 資料處理與計算邏輯
# ==========================================
try:
    returns_pct = [float(x.strip()) for x in returns_input.split(',')]
    returns = [r / 100.0 for r in returns_pct]
except ValueError:
    st.error("請確保輸入格式正確（僅限數字與逗號）")
    st.stop()

current_wealth = 0
cumulative_investment = 0  # 新增：用來記錄累積投入本金
matrix_data = []
wealth_history = [] 

for i, r in enumerate(returns):
    cumulative_investment += annual_investment
    current_wealth = (current_wealth + annual_investment) * (1 + r)
    
    # 矩陣多加一個「累積投入本金」欄位
    matrix_data.append([i + 1, cumulative_investment, f"{r*100:.2f}%", round(current_wealth, 2)])
    wealth_history.append(current_wealth)

df = pd.DataFrame(matrix_data, columns=['年份', '累積本金', '報酬率', '年底財富'])
total_years = len(returns)
final_wealth = current_wealth
total_cost = annual_investment * total_years

# ==========================================
# 老師指定的算法：用終值與幾何平均計算年化報酬
# ==========================================
# 幾何平均年化報酬率 = (期末終值 / 總投入成本) ^ (1 / 總年數) - 1
total_return_ratio = final_wealth / total_cost
geometric_annual_return = (total_return_ratio) ** (1 / total_years) - 1

# 資產本身的年化報酬 (CAGR) 維持不變
asset_cagr = np.prod([1 + r for r in returns]) ** (1 / total_years) - 1

# ==========================================
# 視覺化
# ==========================================
# 區塊 1：四大指標在這
col1, col2, col3, col4 = st.columns(4)
col1.metric(label="總投入成本", value=f"${total_cost:,.0f}")
col2.metric(label="最終財富", value=f"${final_wealth:,.2f}")
col3.metric(label="資產年化報酬 (CAGR)", value=f"{asset_cagr:.2%}")
col4.metric(label="投資人年化報酬 (幾何平均)", value=f"{geometric_annual_return:.2%}")

# 區塊 2：「強制限制高度」
col_left, col_right = st.columns([1.5, 1])

with col_left:
    chart_df = pd.DataFrame({"累積財富": wealth_history}, index=range(1, total_years + 1))
    st.line_chart(chart_df, height=350)

with col_right:
    st.dataframe(df, width='stretch', height=350, hide_index=True)