(function initDates() {
  const today = new Date();
  const tenYearsAgo = new Date(today);
  tenYearsAgo.setFullYear(today.getFullYear() - 10);
  const fmt = (d) => d.toISOString().split('T')[0];
  document.getElementById('start-date').value = fmt(tenYearsAgo);
  document.getElementById('end-date').value = fmt(today);
})();

function toggleDetailModal() {
  document.getElementById('detail-modal').classList.toggle('open');
}
function closeDetailModal(e) {
  if (e.target === document.getElementById('detail-modal')) toggleDetailModal();
}

let chartInstance = null;
let allDateLabels = [];

function initRangeSliders(labels) {
  allDateLabels = labels;
  const max = labels.length - 1;

  const sliderStart = document.getElementById('range-start');
  const sliderEnd   = document.getElementById('range-end');

  sliderStart.max = max;
  sliderStart.value = 0;
  sliderEnd.max = max;
  sliderEnd.value = max;

  updateRangeUI();

  sliderStart.oninput = () => {
    if (+sliderStart.value >= +sliderEnd.value) sliderStart.value = +sliderEnd.value - 1;
    updateRangeUI();
    applyZoom();
  };
  sliderEnd.oninput = () => {
    if (+sliderEnd.value <= +sliderStart.value) sliderEnd.value = +sliderStart.value + 1;
    updateRangeUI();
    applyZoom();
  };
}

function updateRangeUI() {
  const sliderStart = document.getElementById('range-start');
  const sliderEnd   = document.getElementById('range-end');
  const fill        = document.getElementById('range-track-fill');
  const max = +sliderStart.max;
  const s   = +sliderStart.value;
  const e   = +sliderEnd.value;

  const pctS = (s / max) * 100;
  const pctE = (e / max) * 100;
  fill.style.left  = `${pctS}%`;
  fill.style.width = `${pctE - pctS}%`;

  document.getElementById('range-label-start').textContent = allDateLabels[s] ?? '';
  document.getElementById('range-label-end').textContent   = allDateLabels[e] ?? '';
}

function applyZoom() {
  if (!chartInstance) return;
  const s = +document.getElementById('range-start').value;
  const e = +document.getElementById('range-end').value;
  chartInstance.options.scales.x.min = allDateLabels[s];
  chartInstance.options.scales.x.max = allDateLabels[e];
  chartInstance.update('none');
}

function resample(prices, freq) {
  const map = new Map();
  for (const p of prices) {
    const d = new Date(p.date);
    const key = freq === 'monthly'
      ? `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
      : `${d.getFullYear()}`;
    map.set(key, p);
  }
  return Array.from(map.values());
}

function calcMDD(prices) {
  let peak = -Infinity, mdd = 0;
  for (const p of prices) {
    if (p.close > peak) peak = p.close;
    const dd = p.close / peak - 1;
    if (dd < mdd) mdd = dd;
  }
  return mdd;
}

async function runAnalysis() {
  const ticker   = document.getElementById('ticker').value.trim().toUpperCase();
  const start    = document.getElementById('start-date').value;
  const end      = document.getElementById('end-date').value;
  const initial  = parseFloat(document.getElementById('initial-investment').value) || 0;
  const freq     = document.getElementById('freq').value;
  const periodic = parseFloat(document.getElementById('periodic-investment').value) || 0;

  const statusWrap = document.getElementById('status-wrap');
  const statusEl   = document.getElementById('status');
  const btn        = document.getElementById('run-btn');

  statusEl.className = '';
  statusEl.innerHTML = '<span class="spinner"></span>正在從 Yahoo Finance 抓取歷史股價...';
  statusWrap.style.display = 'flex';
  document.getElementById('metrics').style.display = 'none';
  document.getElementById('content-row').style.display = 'none';
  btn.disabled = true;

  try {
    const resp = await fetch(`/api/stock?ticker=${encodeURIComponent(ticker)}&start=${start}&end=${end}`);
    const data = await resp.json();

    if (!resp.ok) {
      statusEl.className = 'error-msg';
      statusEl.textContent = data.error || '發生未知錯誤';
      return;
    }

    const mdd = calcMDD(data);
    const periodPrices = resample(data, freq);

    const returns = [], dateLabels = [];
    for (let i = 1; i < periodPrices.length; i++) {
      returns.push(periodPrices[i].close / periodPrices[i - 1].close - 1);
      dateLabels.push(periodPrices[i].date);
    }

    if (returns.length === 0) {
      statusEl.className = 'error-msg';
      statusEl.textContent = '選擇的日期區間太短，無法計算完整的報酬率。請將起始日期往前調。';
      return;
    }

    let currentWealth = initial, cumulativeInvestment = initial;
    const matrixData = [], wealthHistory = [];

    for (let i = 0; i < returns.length; i++) {
      cumulativeInvestment += periodic;
      currentWealth = (currentWealth + periodic) * (1 + returns[i]);
      matrixData.push({
        date: dateLabels[i],
        cumInvestment: cumulativeInvestment,
        returnRate: returns[i],
        finalWealth: Math.round(currentWealth * 100) / 100,
      });
      wealthHistory.push(currentWealth);
    }

    const totalPeriods   = returns.length;
    const finalWealth    = currentWealth;
    const totalCost      = initial + periodic * totalPeriods;
    const periodsPerYear = freq === 'monthly' ? 12 : 1;
    const yearsPassed    = totalPeriods / periodsPerYear;

    const investorCAGR = totalCost > 0
      ? Math.pow(finalWealth / totalCost, 1 / yearsPassed) - 1 : 0;

    const assetCAGR = Math.pow(
      returns.reduce((acc, r) => acc * (1 + r), 1), 1 / yearsPassed
    ) - 1;

    // Metrics
    document.getElementById('lbl-cost').textContent = `總投入 (${totalPeriods} 期)`;
    document.getElementById('val-cost').textContent =
      `$${totalCost.toLocaleString('en-US', { maximumFractionDigits: 0 })}`;
    document.getElementById('val-final').textContent =
      `$${finalWealth.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    document.getElementById('lbl-asset-cagr').textContent = `${ticker} 年化報酬`;
    document.getElementById('val-asset-cagr').textContent = `${(assetCAGR * 100).toFixed(2)}%`;
    document.getElementById('val-investor-cagr').textContent = `${(investorCAGR * 100).toFixed(2)}%`;
    document.getElementById('val-mdd').textContent = `${(mdd * 100).toFixed(2)}%`;

    // Table
    document.getElementById('table-body').innerHTML = matrixData.map(row => `
      <tr>
        <td>${row.date}</td>
        <td>$${row.cumInvestment.toLocaleString('en-US')}</td>
        <td class="${row.returnRate >= 0 ? 'ret-pos' : 'ret-neg'}">${(row.returnRate * 100).toFixed(2)}%</td>
        <td>$${row.finalWealth.toLocaleString('en-US', { minimumFractionDigits: 2 })}</td>
      </tr>
    `).join('');

    // Chart
    if (chartInstance) chartInstance.destroy();
    const ctx = document.getElementById('wealth-chart').getContext('2d');
    chartInstance = new Chart(ctx, {
      type: 'line',
      data: {
        labels: dateLabels,
        datasets: [{
          label: '累積財富',
          data: wealthHistory,
          borderColor: '#6366f1',
          backgroundColor: (c) => {
            const g = c.chart.ctx.createLinearGradient(0, 0, 0, c.chart.height);
            g.addColorStop(0, 'rgba(99,102,241,0.18)');
            g.addColorStop(1, 'rgba(99,102,241,0)');
            return g;
          },
          fill: true,
          tension: 0.4,
          pointRadius: 0,
          borderWidth: 2.5,
        }],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: 'index', intersect: false },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: '#0f172a',
            titleColor: '#94a3b8',
            bodyColor: '#f1f5f9',
            padding: 10,
            cornerRadius: 8,
            callbacks: {
              label: (c) => ` $${c.parsed.y.toLocaleString('en-US', { minimumFractionDigits: 2 })}`,
            },
          },
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { maxTicksLimit: 8, maxRotation: 0, color: '#94a3b8', font: { size: 11 } },
            border: { display: false },
          },
          y: {
            grid: { color: '#f1f5f9' },
            ticks: {
              color: '#94a3b8',
              font: { size: 11 },
              callback: (v) => v >= 1000000
                ? `$${(v / 1000000).toFixed(1)}M`
                : `$${(v / 1000).toFixed(0)}k`,
            },
            border: { display: false },
          },
        },
      },
    });

    initRangeSliders(dateLabels);

    statusWrap.style.display = 'none';
    document.getElementById('metrics').style.display = 'grid';
    document.getElementById('content-row').style.display = 'grid';

  } catch (err) {
    statusEl.className = 'error-msg';
    statusEl.textContent = `發生錯誤：${err.message}`;
  } finally {
    btn.disabled = false;
  }
}
