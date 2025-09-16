+++
title = "indicator-calculator"
weight = 13
[params]
  menuPre = '<i class="fa-fw fas fa-chart-pie"></i>'
+++

## 🔹 **1. RSI (Relative Strength Index)**

$$
RSI = 100 - \frac{100}{1 + RS}
$$

где

$$
RS = \frac{\text{AvgGain}_{n}}{\text{AvgLoss}_{n}}
$$

* $n$ — окно (обычно 14).
* AvgGain = средний рост за $n$ периодов.
* AvgLoss = среднее падение за $n$ периодов.

---

## 🔹 **2. MACD (Moving Average Convergence Divergence)**

$$
MACD = EMA_{fast}(Price) - EMA_{slow}(Price)
$$

$$
Signal = EMA_{signal}(MACD)
$$

$$
Histogram = MACD - Signal
$$

* fast = 12, slow = 26, signal = 9 (по умолчанию).

---

## 🔹 **3. Bollinger Bands (BBands)**

$$
Middle = SMA_n(Price)
$$

$$
Upper = Middle + k \cdot \sigma
$$

$$
Lower = Middle - k \cdot \sigma
$$

* $n$ — длина окна (обычно 20).
* $\sigma$ — стандартное отклонение цены.
* $k$ — множитель (обычно 2).

---

## 🔹 **4. ATR (Average True Range)**

$$
TR_t = \max(High_t - Low_t, |High_t - Close_{t-1}|, |Low_t - Close_{t-1}|)
$$

$$
ATR = SMA_n(TR)
$$

---

## 🔹 **5. Support / Resistance**

* Локальный минимум в окне $n$:

$$
is\_support_t = Price_t = \min(Price_{t-n}, \dots, Price_{t+n})
$$

* Локальный максимум:

$$
is\_resistance_t = Price_t = \max(Price_{t-n}, \dots, Price_{t+n})
$$

* Уровни группируются (cluster) с толерансом $\pm tol$.

---

## 🔹 **6. Fear & Greed Index (упрощённый)**

$$
FGI = w_1 \cdot RSI + w_2 \cdot \frac{Volume}{SMA(Volume)} + w_3 \cdot \frac{|Price - SR\_Level|}{Price}
$$

* Нормируем в диапазон \[0, 100].
* Интерпретация: **<30 → страх, >70 → жадность**.

---

## 🔹 **7. VWAP (Volume Weighted Average Price)**

$$
VWAP_t = \frac{\sum_{i=1}^{t} (Price_i \cdot Volume_i)}{\sum_{i=1}^{t} Volume_i}
$$

---

## 🔹 **8. OBV (On Balance Volume)**

$$
OBV_t = OBV_{t-1} +
\begin{cases} 
+Volume_t, & Price_t > Price_{t-1} \\ 
-Volume_t, & Price_t < Price_{t-1} \\
0, & \text{иначе} 
\end{cases}
$$

---

## 🔹 **9. SuperTrend**

$$
BasicUpperBand = \frac{High + Low}{2} + m \cdot ATR
$$

$$
BasicLowerBand = \frac{High + Low}{2} - m \cdot ATR
$$

* $m$ — множитель (например, 3).
* SuperTrend = динамическая линия, которая «переключается» в зависимости от пробоя ценой.

---

## 🔹 **10. Volume Profile (гистограмма объёмов по ценовым уровням)**

$$
VP(p) = \sum_{i} Volume_i \quad \text{для всех сделок с ценой в диапазоне } [p, p+\Delta p]
$$

* $\Delta p$ — шаг ценового уровня.

---

## 🔹 **11. Imbalance (Order Book Imbalance)**

$$
Imbalance = \frac{\sum Bids - \sum Asks}{\sum Bids + \sum Asks}
$$

* В норме от -1 до 1.
* > 0 → перевес покупателей, <0 → продавцов.

## 🔹 **12. FGI и Support/Resistance**

   * **FGI (Fear & Greed Index)** — это не чисто технический индикатор, а «мета-оценка» настроения. В упрощённом варианте можно вычислять его как функцию волатильности, объёмов и расстояния до уровней:

     $$
     FGI = w_1 \cdot RSI + w_2 \cdot \frac{\text{Volume}}{\text{MA(Volume)}} + w_3 \cdot \frac{|Price - SR\_Level|}{Price}
     $$

     где $w_i$ — веса (например, 0.4, 0.3, 0.3). Итог нормализуем в диапазон \[0,100].

     > **FGI < 30** → страх (рынок перепродан), **FGI > 70** → жадность (перекуплен).

   * **Support / Resistance**
     Алгоритм:

     1. Вычисляем локальные экстремумы (с помощью `argrelextrema` или через кластеры уровней).
     2. Кластеры уровней аггрегируем с `tol` = 0.1–0.5%.
     3. Сигналы:

        * **Пробой вверх**: цена пересекает ближайший resistance с ростом объёма → сигнал на buy.
        * **Отбой вниз**: цена отталкивается от support (разворот свечи + RSI < 30) → buy.
        * Аналогично для short при пробое вниз или отбое от resistance.

## 🔹 **13. Дополнительные индикаторы**

   * **VWAP (Volume Weighted Average Price)**:

     $$
     VWAP = \frac{\sum (Price_i \cdot Volume_i)}{\sum Volume_i}
     $$

     Хорошо работает в backfill: можно хранить внутридневной VWAP и проверять, выше/ниже ли текущая цена.

   * **OBV (On Balance Volume)**:

     $$
     OBV_t = OBV_{t-1} + \begin{cases} 
     Volume_t, & Price_t > Price_{t-1} \\ 
     -Volume_t, & Price_t < Price_{t-1} \\
     0, & \text{иначе} 
     \end{cases}
     $$

     Рост цены при росте OBV подтверждает тренд.

   * **SuperTrend** (трендовый фильтр):
     Основан на ATR:

     $$
     \text{UpperBand} = \frac{High+Low}{2} + m \cdot ATR
     $$

     $$
     \text{LowerBand} = \frac{High+Low}{2} - m \cdot ATR
     $$

     где $m$ — множитель (например, 3). Линия SuperTrend переключается в зависимости от пробоя свечой.

## 🔹 **14. Backfill через Kafka**
   Всё логично:

   * создаём консюмера с `group.id = f"backfill-{time.time()}"`,
   * `auto_offset_reset="earliest"`,
   * обрабатываем все сообщения с начала топиков `orderbook/trades`,
   * агрегируем в свечи + индикаторы,
   * публикуем только в **финальный топик** (interactive отключаем),
   * завершаем consumer по достижении конца лога.