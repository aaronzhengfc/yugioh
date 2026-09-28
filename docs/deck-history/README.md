# 历史赛事卡组档案 · 第一批

已整理 2003—2026 年时间线：21 届世界赛、83 条前列选手与卡组类型记录；2020—2022 标为世界赛停办。**完整录入配方与搭配分析的是 2016 年冠亚季军 3 套。其余年份目前是来源索引，不代表配方已经核对完成。**

先看 [2016 年三套卡组与搭配比较](SAMPLE.md)，或查看 [结构化样例](wcs2016-sample.json)。

## 为什么按比赛配方组织

以「年份 → 比赛 → 选手与名次 → 实际配方 → 玩法与搭配分析」组织。玩法名称可有别名，一种玩法可关联多份选手配方。同年的世界赛、OCG地区赛、TCG赛事须分别记录；世界赛配方不能直接标作普通OCG配方。

## 已找到的历年入口

下表的中文卡组名为便于阅读的编辑译名。点年份查看来源和选手；原名、名次、地区和收录状态保存在 events-index.json。

| 年份 | 冠军卡组 | 亚军卡组 | 季军／并列四强 |
|---|---|---|---|
| [2003](https://roadoftheking.com/yu-gi-oh-world-championship-2003/) | 手牌破坏 | 手牌破坏 | 手牌破坏 |
| [2004](https://roadoftheking.com/yu-gi-oh-world-championship-2004/) | 混沌 | 混沌 | 混沌 |
| [2005](https://roadoftheking.com/yu-gi-oh-world-championship-2005/) | 凤凰神变异混沌 | 卡组破坏 | 机械混沌 |
| [2006](https://roadoftheking.com/yu-gi-oh-world-championship-2006/) | 混沌 | 暗黑界混沌 | 遗言怪混沌 |
| [2007](https://roadoftheking.com/yu-gi-oh-world-championship-2007/) | 炮击士帝 | 机械 | 效果伤害（烧血） |
| [2008](https://roadoftheking.com/yu-gi-oh-world-championship-2008/) | 剑斗兽 | 剑斗兽 | 光道 |
| [2009](https://roadoftheking.com/yu-gi-oh-world-championship-2009/) | 黑羽 | 救援猫剑斗兽 | 黑羽 |
| [2010](https://roadoftheking.com/yu-gi-oh-world-championship-2010/) | 青蛙先攻一回杀 | 黑羽 | 神光之宣告者 |
| [2011](https://roadoftheking.com/yu-gi-oh-world-championship-2011/) | 代行天使 | 废品二重身 | 废品二重身 |
| [2012](https://roadoftheking.com/yu-gi-oh-world-championship-2012/) | 甲虫装机 | 甲虫装机 | 甲虫装机 |
| [2013](https://roadoftheking.com/yu-gi-oh-world-championship-2013/) | 征龙 | 魔导／魔导书 | 征龙 |
| [2014](https://roadoftheking.com/yu-gi-oh-world-championship-2014/) | 永火 | 古遗物虫惑魔 | 永火 |
| [2015](https://roadoftheking.com/yu-gi-oh-world-championship-2015/) | 星因士 | 影灵衣 | 影灵衣 |
| [2016](https://roadoftheking.com/yu-gi-oh-world-championship-2016/) | 青眼 | 青眼 | 威风妖怪 |
| [2017](https://roadoftheking.com/yu-gi-oh-world-championship-2017/) | 真龙皇龙星恐龙 | 真龙皇龙星恐龙 | 削命真龙 |
| [2018](https://roadoftheking.com/yu-gi-oh-world-championship-2018/) | 淘气仙星 | 幻变骚灵 | 刚鬼 |
| [2019](https://roadoftheking.com/yu-gi-oh-world-championship-2019/) | 转生炎兽 | 转生炎兽 | 转生炎兽 |
| [2020](https://www.yugioh-card.com/eu/konami-announces-the-return-of-the-yu-gi-oh-world-championship-for-2023/) | 世界赛停办 | — | — |
| [2021](https://www.yugioh-card.com/eu/konami-announces-the-return-of-the-yu-gi-oh-world-championship-for-2023/) | 世界赛停办 | — | — |
| [2022](https://www.yugioh-card.com/eu/konami-announces-the-return-of-the-yu-gi-oh-world-championship-for-2023/) | 世界赛停办 | — | — |
| [2023](https://roadoftheking.com/yu-gi-oh-world-championship-2023/) | 深渊之兽龙连接 | 天威相剑 | 征服斗魂、深渊之兽龙连接 |
| [2024](https://roadoftheking.com/yu-gi-oh-world-championship-2024/) | 刻魔尤贝尔 | 刻魔蛇眼 | 刻魔蛇眼、刻魔蛇眼炎王 |
| [2025](https://roadoftheking.com/yu-gi-oh-world-championship-2025/) | K9征服斗魂 | 月光 | Yummy、闪刀姬 |
| [2026](https://roadoftheking.com/yu-gi-oh-world-championship-2026/) | 杀手级调整曲 | Fallen Light and Darkness Ritual | 闪刀姬、杀手级调整曲 |

## 内容示例与可继续收集的方向

- 2003 前三名都是手牌破坏，可比较同一种老玩法的不同用卡。
- 2005 亚军是卡组破坏，区别于让对手丢手牌。
- 2007 季军是效果伤害卡组，可以补足单看冠军时缺失的玩法。
- 2016 冠亚军都是青眼、季军是威风妖怪，已完成三份实际配方样例。
- 2018 前四分别是淘气仙星、幻变骚灵、刚鬼、闪刀姬，适合做同年不同玩法对比。

## 结构与接入方式

- `events-index.json`：21届赛事的前列结果，以及3个停办年份。2023—2026保留3–4并列名次；2011只有搜索摘要核实到前三名，第四名暂缺。2006第四名卡组类型在来源中为空，保持未知。
- `wcs2016-sample.json`：赛事、来源、卡牌索引、配方、编辑分析、冠亚军逐卡差异。
- `sources/wcs2016-podium.json`：从官方数据库页面录入的英文卡名和原始数量。
- `sources/wcs2016-analysis.json`：搭配解释，全部标为编辑分析，未伪装成选手原话。
- `ydk/`：三份从已核对配方生成的YDK，不冒充选手原始上传文件。
- `validation.json`：卡牌映射、数量和现有冠军配方交叉核对结果。
- `build_sample.py`：只读访问 App 数据库，重新生成样例和核对报告。

本次没有改动 App 数据库。原有冠军资料仍在 yugioh-backup/world-championship-decks；本目录新增内容先用于评审。

## 核对结果与限制

三套主卡数量分别为42、40、41，额外与副卡均为15；共87种卡牌全部映射到本地数据库。3个重名异画条目使用相同Konami卡号确认身份，并在cards[].alternate_local_ids保留本地别名。2016冠军配方与App现有记录逐项一致。

页面当前禁限提示不能当成历史禁限表；历史规则与旧效果文本尚未完整归档，因此暂不声称通过历史合法性审核。分析用于解释构筑思路；后续精确展开、换备表应补充选手讲解或实战记录。

重新生成：`python3 docs/deck-history/build_sample.py`。


## App 数据库与界面（2026-09-29）

`import_history.py --apply` 将资料写入 `yugioh/cards.cdb`，写入前在 `/tmp` 创建备份；不加参数只验证输入。新增三张表：

- `history_event`：24 个年份、举办状态、来源与验证情况。
- `history_deck`：83 条名次、选手、地区、卡组类型、配方状态、来源，以及 `analysisJson` 中文介绍。
- `history_card`：可关联本地 `newpro.id` 的卡牌与主／副／额外数量，独立保留各选手配方。

已接入原有 21 份冠军档案，加上 2016 年亚军、季军，共 23 份可查看配方。2005 年冠军副卡缺失；60 条记录尚无核对后的配方；2011 年第四名仍未收录。原有 `newdeck`、收藏和自组卡组不变。

介绍保存在数据库，区分 `recipe_editorial`（2016 三份配方编辑解读）、`recipe_observation`（类型介绍与实际配比观察）、`type_overview`（未收录配方的类型简介）。`sources/strategy-introductions.json` 是编辑编写的类型概述，不是选手采访；新类型资料不够时显示待考证，不生成假连招。

Tab2 按年份读取上述表；详情分为构筑解读与卡牌配方，缺失配方不可切换，来源可在内置浏览器查看。修改数据后重新导入数据库即可，无需把介绍硬编码到 Swift。
