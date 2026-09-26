const test = require('node:test');
const assert = require('node:assert/strict');
const { createLoader } = require('./ets-loader.cjs');

const TODAY = new Date(2026, 8, 26); // 2026-09-26，周六

function logOn(date, id = date) {
  return { id, category: 'log', recordDate: date, createdAt: date + 'T08:00:00' };
}
function emotionOn(date, level, subEmotion = null, id = 'e' + date + level) {
  return { id, level, subEmotion, recordDate: date, createdAt: date + 'T09:00:00' };
}

test('comparison concludes more frequent when current window beats previous equal-length window', () => {
  const { reviewComparison, reviewDays } = createLoader()('data/ReviewWindow');
  // week of 2026-09-26 = 09-21..09-26；previous = 09-15..09-20
  const logs = [logOn('2026-09-22'), logOn('2026-09-24', 'b'), logOn('2026-09-25', 'c'),
    logOn('2026-09-26', 'e'), logOn('2026-09-17', 'd')];
  const result = reviewComparison(logs, [], 'week', TODAY);
  assert.equal(reviewDays('week', TODAY).length, 6);
  assert.equal(result.currentCount, 4);
  assert.equal(result.previousCount, 1);
  assert.equal(result.insufficient, false);
  assert.equal(result.conclusion, '这周你记录得比上周更频繁');
});

test('comparison concludes less active / on par and uses window labels', () => {
  const { reviewComparison } = createLoader()('data/ReviewWindow');
  const less = reviewComparison([logOn('2026-09-16'), logOn('2026-09-18', 'b'), logOn('2026-09-19', 'c')],
    [emotionOn('2026-09-20', 1), emotionOn('2026-09-22', 1)], 'week', TODAY);
  assert.equal(less.currentCount, 1);
  assert.equal(less.previousCount, 4);
  assert.equal(less.conclusion, '这周不如上周活跃');
  const par = reviewComparison([logOn('2026-09-22'), logOn('2026-09-16', 'b'),
    logOn('2026-09-23', 'c'), logOn('2026-09-17', 'd'), logOn('2026-09-25', 'e'), logOn('2026-09-18', 'f')], [], 'week', TODAY);
  assert.equal(par.conclusion, '这周与上周持平');
  const rolling = reviewComparison([], [], '30', TODAY);
  assert.equal(rolling.currentLabel, '近 30 天');
  assert.equal(rolling.previousLabel, '之前 30 天');
});

test('comparison stays silent when both windows have fewer than 5 entries combined', () => {
  const { reviewComparison } = createLoader()('data/ReviewWindow');
  const result = reviewComparison([logOn('2026-09-25'), logOn('2026-09-17', 'b')], [], 'week', TODAY);
  assert.equal(result.insufficient, true);
  assert.equal(result.conclusion, '继续记录，回顾会慢慢清晰');
  assert.equal(result.currentCount, 1);
  assert.equal(result.previousCount, 1);
});

test('comparison mentions emotion shift only with 2+ emotion records per window and diff >= 1', () => {
  const { reviewComparison } = createLoader()('data/ReviewWindow');
  const logs = [logOn('2026-09-22'), logOn('2026-09-23', 'b'), logOn('2026-09-16', 'c')];
  const happier = reviewComparison(logs,
    [emotionOn('2026-09-22', 2), emotionOn('2026-09-24', 2),
      emotionOn('2026-09-16', -2), emotionOn('2026-09-18', -2)], 'week', TODAY);
  assert.equal(happier.conclusion, '这周你记录得比上周更频繁，情绪整体更积极了一些');
  const sparseEmotion = reviewComparison([...logs, logOn('2026-09-25', 'd')], [emotionOn('2026-09-22', 3)], 'week', TODAY);
  assert.equal(sparseEmotion.conclusion, '这周你记录得比上周更频繁');
  assert.equal(sparseEmotion.currentEmotionAvg, 3);
  assert.equal(sparseEmotion.previousEmotionAvg, null);
});

test('previous window is the equal-length span immediately before the current one', () => {
  const { reviewComparison, reviewDays } = createLoader()('data/ReviewWindow');
  // 2026-09-26 是 9 月第 26 天：本月窗口 26 天，前窗口为 08-31 往前 26 天
  const logs = [logOn('2026-08-31'), logOn('2026-08-20', 'b'), logOn('2026-08-06', 'c')];
  const result = reviewComparison(logs, [], 'month', TODAY);
  assert.equal(reviewDays('month', TODAY).length, 26);
  assert.equal(result.previousCount, 3);
  assert.equal(result.currentCount, 0);
  assert.equal(result.conclusion, '继续记录，回顾会慢慢清晰');
});

test('emotion distribution buckets levels and breaks down negative sub-emotions', () => {
  const { emotionDistribution } = createLoader()('data/ReviewWindow');
  const days = ['2026-09-24', '2026-09-25'];
  const emotions = [
    emotionOn('2026-09-24', 2),
    emotionOn('2026-09-24', 0, null, 'n'),
    emotionOn('2026-09-25', -2, 'sad'),
    emotionOn('2026-09-25', -1, 'sad', 's2'),
    emotionOn('2026-09-25', -3, 'angry', 's3'),
    emotionOn('2026-09-26', 1) // 窗口外
  ];
  const result = emotionDistribution(emotions, days);
  assert.equal(result.positive, 1);
  assert.equal(result.neutral, 1);
  assert.equal(result.negative, 3);
  assert.equal(result.total, 5);
  assert.deepEqual(result.subEmotions.map(s => [s.key, s.name, s.count]),
    [['sad', '伤心', 2], ['angry', '生气', 1]]);
});

test('emotion distribution with no records is empty', () => {
  const { emotionDistribution } = createLoader()('data/ReviewWindow');
  const result = emotionDistribution([], ['2026-09-26']);
  assert.equal(result.total, 0);
  assert.deepEqual(result.subEmotions, []);
});
