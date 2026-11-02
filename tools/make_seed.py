#!/usr/bin/env python3
"""生成随包附带的小型种子词库 (Resources/lexicon.tsv, Resources/gloss_en.tsv)。
完整词库请运行 tools/build_lexicon.py。种子数据为手写，仅用于开箱即用与测试。"""
import os, sys

CHARS = """
a: 啊 阿
ai: 爱 哀 埃
an: 安 按 暗 案
ang: 昂
ao: 奥 傲
ba: 吧 把 八 爸 巴
bai: 白 百 摆 败
ban: 办 半 班 般 板
bang: 帮 棒 邦
bao: 包 保 报 宝 抱
bei: 北 被 背 备 杯 悲
ben: 本 笨
bi: 比 必 笔 毕 避 币
bian: 变 边 便 遍 编
biao: 表 标
bie: 别
bing: 并 病 冰 兵
bu: 不 步 部 布 补
ca: 擦
cai: 才 菜 财 彩 猜 采
can: 参 餐 惨
cang: 仓 藏
cao: 草 操
ce: 策 测 册
ceng: 层 曾
cha: 查 差 茶 察
chai: 拆
chan: 产
chang: 长 常 场 唱 厂 尝
chao: 超 朝 吵 抄
che: 车 彻
chen: 陈 沉 晨
cheng: 成 城 程 称 乘 承
chi: 吃 迟 持 池 尺
chong: 重 冲 充
chou: 抽 愁 丑
chu: 出 初 处 除 楚 储
chuan: 传 船 穿 串
chuang: 创 窗 床
chui: 吹
chun: 春 纯
ci: 次 此 词 刺 磁
cong: 从 聪
cu: 粗 促
cun: 村 存
cuo: 错 措
da: 大 打 达
dai: 带 代 待 袋 戴
dan: 但 单 担 蛋 淡
dang: 当 党 挡
dao: 到 道 导 倒 刀 岛
de: 的 得 地 德
deng: 等 灯 登
di: 地 第 底 低 弟 敌
dian: 点 电 店 典
diao: 调 掉 钓
die: 跌
ding: 定 订 顶 钉
dong: 东 动 冬 懂 洞
dou: 都 斗 豆
du: 读 度 独 毒 堵
duan: 短 段 断
dui: 对 队
dun: 顿 吨
duo: 多 朵 躲
e: 额 饿 恶 鹅
en: 恩
er: 二 而 儿 耳
fa: 发 法 罚
fan: 反 饭 翻 烦 范 犯
fang: 方 放 房 访 防
fei: 非 飞 费 肥
fen: 分 份 粉
feng: 风 封 丰 峰 疯
fo: 佛
fou: 否
fu: 副 服 福 父 付 夫 负 富
gai: 改 该 概
gan: 感 干 敢 赶
gang: 刚 钢 港
gao: 高 告 搞 稿
ge: 个 各 歌 格 割 哥
gei: 给
gen: 根 跟
geng: 更 耕
gong: 工 公 共 功 供 攻
gou: 够 构 狗 购
gu: 古 故 顾 骨 股 鼓
gua: 挂 刮
guai: 怪
guan: 关 管 观 馆 官
guang: 光 广
gui: 贵 规 归 鬼
guo: 国 过 果 锅
ha: 哈
hai: 还 海 孩 害
han: 汉 喊 寒 韩
hang: 行 航
hao: 好 号 浩 毫
he: 和 合 河 何 喝 核
hei: 黑
hen: 很 恨
heng: 横 衡
hong: 红 洪 宏
hou: 后 候 厚 喉
hu: 户 湖 护 忽 胡 虎
hua: 话 花 华 画 划
huai: 坏 怀
huan: 换 欢 环 缓
huang: 黄 皇 慌
hui: 会 回 汇 灰 辉
hun: 婚 混
huo: 活 火 或 获 货
ji: 机 几 己 记 级 极 济 及 即 集 急 季 寄
jia: 家 加 假 价 架 夹
jian: 见 间 件 建 简 减 剪 检
jiang: 将 讲 江 降 奖 姜
jiao: 教 叫 交 脚 角 觉 较 焦
jie: 接 结 街 节 姐 解 界 借 介
jin: 进 近 今 金 紧 尽 禁
jing: 经 京 精 静 境 景 惊 睛
jiu: 就 九 久 酒 旧
ju: 句 局 举 居 巨 具 聚 剧
juan: 卷 捐
jue: 决 绝
jun: 军 均 君
ka: 卡
kai: 开 凯
kan: 看 砍
kang: 康 抗
kao: 考 靠 烤
ke: 可 科 课 客 刻 克 渴
ken: 肯
keng: 坑
kong: 空 控 恐
kou: 口 扣
ku: 苦 库 哭 酷
kua: 夸
kuai: 快 块 筷
kuan: 宽
kuang: 况 矿 狂
kui: 亏
kun: 困
kuo: 扩
la: 拉 啦 辣 垃
lai: 来 赖
lan: 蓝 烂 懒 兰
lang: 浪 狼
lao: 老 劳 牢
le: 了 乐
lei: 类 累 泪 雷
leng: 冷
li: 里 力 理 利 立 例 历 离 礼 李
lian: 连 联 脸 练 恋
liang: 两 量 亮 良 凉
liao: 料 聊
lie: 列 烈
lin: 林 临 邻
ling: 令 领 零 另 灵
liu: 六 流 留 刘
long: 龙 隆
lou: 楼 漏
lu: 路 陆 录 鲁 卢
lv: 绿 率 旅 律 履
luan: 乱
lun: 论 轮
luo: 落 罗 洛
ma: 吗 妈 马 麻
mai: 买 卖 麦
man: 满 慢 漫
mang: 忙 盲
mao: 毛 帽 猫
me: 么
mei: 没 每 美 妹 梅
men: 们 门
meng: 梦 猛 蒙
mi: 米 密 秘 迷
mian: 面 免 棉
miao: 秒 妙 苗
min: 民 敏
ming: 明 名 命
mo: 模 摸 默 末 魔
mou: 某
mu: 目 母 木 幕 牧
na: 那 拿 哪 纳
nai: 奶 耐
nan: 难 南 男
nao: 脑 闹
ne: 呢
nei: 内
neng: 能
ni: 你 尼 泥 拟 逆
nian: 年 念
niang: 娘
niao: 鸟
nin: 您
ning: 宁 凝
niu: 牛 扭
nong: 农 浓
nu: 努 怒
nv: 女
nuan: 暖
nuo: 诺
ou: 欧 偶
pa: 怕 爬 帕
pai: 排 牌 拍 派
pan: 判 盘 攀
pang: 旁 胖
pao: 跑 炮 泡
pei: 配 陪 培
pen: 盆
peng: 朋 碰 棚
pi: 皮 批 脾 匹
pian: 片 篇 骗
piao: 票 漂
pin: 品 贫 拼
ping: 平 瓶 评 凭
po: 破 迫 婆
pu: 普 铺 朴
qi: 起 其 期 气 七 器 汽 奇 企 启
qia: 恰
qian: 前 钱 千 签 浅 欠
qiang: 强 墙 抢
qiao: 桥 巧 敲 悄
qie: 且 切
qin: 亲 琴 勤 秦
qing: 请 情 清 青 轻 晴 庆
qiong: 穷
qiu: 求 球 秋
qu: 去 区 取 趣 曲
quan: 全 权 圈 泉
que: 却 确 缺
qun: 群
ran: 然 燃
rang: 让 嚷
rao: 绕
re: 热
ren: 人 认 任 仁
reng: 仍 扔
ri: 日
rong: 容 荣 融
rou: 肉 柔
ru: 如 入 乳
ruan: 软
rui: 瑞 锐
run: 润
ruo: 若 弱
sa: 撒
sai: 赛 塞
san: 三 散 伞
sang: 桑
sao: 扫 嫂
se: 色
sen: 森
seng: 僧
sha: 杀 傻 沙
shai: 晒
shan: 山 删 闪 善
shang: 上 商 伤 尚
shao: 少 烧 绍
she: 社 设 舍 蛇 射
shei: 谁
shen: 什 身 深 神 申 甚
sheng: 生 声 省 胜 升 剩
shi: 是 时 事 十 实 使 市 世 食 始 师 试 式 室
shou: 手 受 收 首 守 寿
shu: 书 数 树 输 属 术 叔 熟
shua: 刷
shuai: 帅 摔
shuan: 拴
shuang: 双 爽 霜
shui: 水 睡 税
shun: 顺
shuo: 说 硕
si: 四 死 思 司 私 似
song: 送 松 宋
sou: 搜
su: 速 素 诉 宿
suan: 算 酸
sui: 岁 随 虽 碎
sun: 孙 损
suo: 所 缩 索
ta: 他 她 它 塔
tai: 太 台 态 抬
tan: 谈 谭 弹 探 叹
tang: 糖 汤 堂 躺
tao: 套 逃 桃 讨
te: 特
teng: 疼 腾
ti: 提 体 题 替 踢
tian: 天 田 甜 填
tiao: 条 跳
tie: 铁 贴
ting: 听 停 庭 挺
tong: 同 通 痛 统 童
tou: 头 投 透
tu: 图 土 突 吐
tuan: 团
tui: 推 腿 退
tun: 吞
tuo: 拖 脱
wa: 瓦 挖 哇
wai: 外
wan: 完 万 晚 玩 弯 碗
wang: 王 网 往 忘 望
wei: 为 位 未 味 微 围 伟 卫 威
wen: 问 文 闻 稳 温
weng: 翁
wo: 我 握 窝
wu: 无 五 物 务 武 误 午 舞 屋
xi: 西 希 习 系 息 洗 喜 细 席
xia: 下 夏 吓 瞎
xian: 现 先 县 线 限 显 鲜 闲 献
xiang: 想 向 相 像 香 响 项 象
xiao: 小 笑 校 消 效 晓 销
xie: 写 些 谢 鞋 血 斜 协
xin: 新 心 信 辛 欣
xing: 行 性 星 形 兴 型 醒 姓
xiong: 兄 熊 胸
xiu: 休 修 秀 袖
xu: 需 许 续 虚 序
xuan: 选 宣 旋
xue: 学 雪
xun: 寻 训 讯 迅
ya: 呀 压 牙 亚 鸭
yan: 眼 言 研 烟 严 颜 演 验 盐 延 沿
yang: 样 阳 养 羊 洋 央
yao: 要 药 摇 遥 腰 邀
ye: 也 夜 业 页 野 叶
yi: 一 以 意 已 义 易 医 衣 亿 艺 移 议 译
yin: 因 音 引 银 印 饮
ying: 应 英 影 营 赢 硬
yo: 哟
yong: 用 永 勇 拥
you: 有 又 友 由 游 油 右 优 邮
yu: 于 与 语 雨 鱼 育 遇 预 玉 宇
yuan: 元 原 院 愿 远 员 园 圆
yue: 月 越 约 阅
yun: 云 运 允 孕
za: 杂 砸
zai: 在 再 载 灾
zan: 赞 暂 咱
zang: 脏 葬
zao: 早 造 糟 噪
ze: 则 责 择
zei: 贼
zen: 怎
zeng: 增 赠
zha: 炸 扎 眨
zhai: 摘 窄 宅
zhan: 站 战 展 占
zhang: 长 张 章 掌 涨
zhao: 找 着 招 照 赵
zhe: 这 者 哲 折
zhen: 真 镇 针 阵 珍
zheng: 正 整 政 争 证 郑
zhi: 之 只 知 直 制 治 指 至 质 志 纸
zhong: 中 种 众 钟
zhou: 周 州 洲 粥
zhu: 主 住 注 助 著 竹 筑
zhua: 抓
zhuan: 转 专 赚
zhuang: 装 状 壮
zhui: 追 坠
zhun: 准
zhuo: 桌 捉
zi: 子 自 字 资 紫
zong: 总 宗 综
zou: 走 邹
zu: 组 足 族 租
zuan: 钻
zui: 最 罪 嘴 醉
zun: 尊
zuo: 做 作 坐 座 左 昨
"""

# 多音字补充读音 (读音, 字, 相对权重)
EXTRA_READINGS = [
    ("chong","重",0.6), ("hai","还",0.9), ("huan","还",0.5), ("hang","行",0.5), ("xing","行",1.0),
    ("le","乐",0.6), ("yue","乐",0.3), ("liao","了",0.5), ("di","地",0.5), ("de","得",0.8),
    ("dei","得",0.3), ("zhe","着",0.6), ("zhao","着",0.5), ("zhuo","着",0.2), ("chang","长",0.7),
    ("zhang","长",0.8), ("dou","都",1.0), ("du","都",0.3), ("jiao","觉",0.5), ("jue","觉",0.6),
    ("zhong","重",0.8), ("jiao","角",0.5), ("jue","角",0.3), ("chuan","传",0.8), ("zhuan","传",0.3),
    ("hao","好",1.0), ("hao","号",0.5), ("tiao","调",0.5), ("diao","调",0.4), ("bian","便",0.5),
    ("pian","便",0.2), ("zhong","种",0.8), ("chu","处",0.6), ("shu","数",0.7), ("shuo","数",0.1),
    ("yue","月",1.0), ("xue","血",0.6), ("xie","血",0.3), ("xin","新",1.0), ("jiang","将",0.8),
]

# 词语: 拼音|词|英文译词|频次
WORDS = """
ni hao|你好|hello|900
xie xie|谢谢|thanks; thank you|900
zai jian|再见|goodbye|700
dui bu qi|对不起|sorry|600
mei guan xi|没关系|it's okay|500
peng you|朋友|friend|800
xue xi|学习|to study; to learn|800
gong zuo|工作|work; job|900
jin tian|今天|today|900
ming tian|明天|tomorrow|800
zuo tian|昨天|yesterday|700
xian zai|现在|now|900
shi jian|时间|time|900
shen me|什么|what|1000
wei shen me|为什么|why|900
zen me|怎么|how|900
zen me yang|怎么样|how about|700
ke yi|可以|can; may|1000
bu shi|不是|is not|1000
mei you|没有|have not; there is not|1000
xi huan|喜欢|to like|900
zhi dao|知道|to know|900
jue de|觉得|to feel; to think|900
yin wei|因为|because|900
suo yi|所以|therefore|900
dan shi|但是|but|900
ru guo|如果|if|900
yi jing|已经|already|900
yi ge|一个|one; a|1000
wo men|我们|we; us|1000
ni men|你们|you (plural)|800
ta men|他们|they; them|900
da jia|大家|everyone|800
zi ji|自己|oneself|900
zhong guo|中国|China|1000
bei jing|北京|Beijing|800
shang hai|上海|Shanghai|800
shi jie|世界|world|900
guo jia|国家|country|900
xue xiao|学校|school|800
lao shi|老师|teacher|800
xue sheng|学生|student|800
tong xue|同学|classmate|600
gong si|公司|company|800
dian nao|电脑|computer|800
shou ji|手机|mobile phone|800
wang luo|网络|network|700
ruan jian|软件|software|700
cheng xu|程序|program|700
kai fa|开发|to develop|700
she ji|设计|design|700
shu ru fa|输入法|input method|600
pin yin|拼音|pinyin|600
han zi|汉字|Chinese character|600
yu yan|语言|language|700
ying yu|英语|English|700
ri yu|日语|Japanese|500
fan yi|翻译|to translate|600
dan ci|单词|word|500
ci hui|词汇|vocabulary|500
tong ji|统计|statistics|500
she zhi|设置|settings|500
wen jian|文件|file|600
wen zi|文字|text|500
wen ti|问题|problem; question|900
da an|答案|answer|500
ming bai|明白|to understand|700
qing chu|清楚|clear|600
zhong yao|重要|important|800
xu yao|需要|to need|900
ying gai|应该|should|900
ke neng|可能|maybe; possible|900
yi ding|一定|certainly|800
fei chang|非常|very|900
te bie|特别|especially|700
bi jiao|比较|relatively|700
hai shi|还是|still; or|900
huo zhe|或者|or|800
er qie|而且|moreover|700
sui ran|虽然|although|800
ran hou|然后|then|900
kai shi|开始|to begin|900
jie shu|结束|to end|700
ji xu|继续|to continue|700
wan cheng|完成|to complete|700
cheng gong|成功|success|700
shi bai|失败|to fail|600
sheng huo|生活|life|800
jia ting|家庭|family|600
hai zi|孩子|child|800
fu mu|父母|parents|600
ba ba|爸爸|dad|700
ma ma|妈妈|mom|700
ge ge|哥哥|older brother|500
jie jie|姐姐|older sister|500
di di|弟弟|younger brother|500
mei mei|妹妹|younger sister|500
chi fan|吃饭|to eat a meal|700
he shui|喝水|to drink water|500
shui jiao|睡觉|to sleep|700
qi chuang|起床|to get up|500
shang ban|上班|to go to work|600
xia ban|下班|to get off work|500
hui jia|回家|to go home|600
tian qi|天气|weather|700
xia yu|下雨|to rain|500
hao chi|好吃|delicious|600
hao kan|好看|good-looking|600
hao ting|好听|pleasant to hear|500
piao liang|漂亮|beautiful|600
gao xing|高兴|happy|700
kuai le|快乐|happy; joyful|700
xing fu|幸福|happiness|600
jian kang|健康|health|600
shen ti|身体|body|700
yi yuan|医院|hospital|600
yi sheng|医生|doctor|600
yin hang|银行|bank|600
shang dian|商店|shop|500
chao shi|超市|supermarket|500
ka fei|咖啡|coffee|600
ping guo|苹果|apple|600
mi fan|米饭|rice|500
shui guo|水果|fruit|600
shi hou|时候|time; moment|1000
di fang|地方|place|900
dong xi|东西|thing|900
shi qing|事情|matter|900
ban fa|办法|method|700
ji hui|机会|opportunity|700
fang fa|方法|method|700
jie guo|结果|result|700
yuan yin|原因|reason|700
jing yan|经验|experience|600
jing ji|经济|economy|700
she hui|社会|society|700
zheng fu|政府|government|600
wen hua|文化|culture|700
li shi|历史|history|700
ke xue|科学|science|700
ji shu|技术|technology|800
shu ju|数据|data|800
xin xi|信息|information|800
xi tong|系统|system|800
fu wu|服务|service|700
chan pin|产品|product|700
shi chang|市场|market|600
jia ge|价格|price|600
zhi liang|质量|quality|600
an quan|安全|safety; secure|700
huan jing|环境|environment|700
neng li|能力|ability|700
guan xi|关系|relationship|800
ying xiang|影响|influence|700
bian hua|变化|change|700
fa zhan|发展|development|800
ti gao|提高|to improve|700
zeng jia|增加|to increase|600
jian shao|减少|to decrease|600
yan jiu|研究|research|700
fen xi|分析|analysis|700
bao gao|报告|report|600
ji hua|计划|plan|700
xiang mu|项目|project|700
guan li|管理|to manage|700
tuan dui|团队|team|600
hui yi|会议|meeting|600
tao lun|讨论|to discuss|600
jue ding|决定|to decide|700
xuan ze|选择|to choose|700
zhi chi|支持|to support|700
bang zhu|帮助|to help|800
huan ying|欢迎|welcome|600
gan xie|感谢|to thank|600
sheng ri|生日|birthday|500
chun jie|春节|Spring Festival|500
zhou mo|周末|weekend|600
xing qi|星期|week|600
jin nian|今年|this year|600
qu nian|去年|last year|500
ming nian|明年|next year|500
zao shang|早上|morning|600
wan shang|晚上|evening|700
zhong wu|中午|noon|500
xia wu|下午|afternoon|600
yi qi|一起|together|800
yi yang|一样|the same|700
yi xia|一下|a bit|800
yi xie|一些|some|800
you dian|有点|a little|700
bu yao|不要|do not want|800
bu hui|不会|will not; cannot|800
bu neng|不能|cannot|800
bu cuo|不错|not bad|700
bu hao|不好|not good|600
hen hao|很好|very good|700
tai hao le|太好了|great|500
zhen de|真的|really|800
dang ran|当然|of course|800
ye xu|也许|perhaps|600
da gai|大概|probably|600
yi qian|以前|before|800
yi hou|以后|after; later|800
zhi qian|之前|before|700
zhi hou|之后|after|700
tong shi|同时|at the same time|700
bao kuo|包括|to include|600
guan yu|关于|about|700
dui yu|对于|regarding|700
gen ju|根据|according to|700
tong guo|通过|through|800
you yu|由于|due to|700
zuo wei|作为|as|700
cheng wei|成为|to become|700
jin xing|进行|to carry out|800
shi xian|实现|to realize|700
ti gong|提供|to provide|700
shi yong|使用|to use|800
can jia|参加|to participate|600
lai zi|来自|to come from|600
shu yu|属于|to belong to|600
wo ai ni|我爱你|I love you|500
xiang fa|想法|idea|600
zhong wen|中文|Chinese language|700
ren men|人们|people|700
ren min|人民|the people|600
gong zuo shi|工作室|studio|300
dian ying|电影|movie|700
yin yue|音乐|music|700
shu ben|书本|book|300
du shu|读书|to study; to read|600
xie zi|写字|to write|400
shuo hua|说话|to speak|600
ting shuo|听说|to hear that|500
kan jian|看见|to see|600
zou lu|走路|to walk|500
kai che|开车|to drive|600
zuo che|坐车|to take a car|400
fei ji|飞机|airplane|600
huo che|火车|train|500
di tie|地铁|subway|600
lu shang|路上|on the road|500
qi che|汽车|car|600
jia li|家里|at home|600
wai mian|外面|outside|500
li mian|里面|inside|500
shang mian|上面|above|500
xia mian|下面|below|500
qian mian|前面|in front|500
hou mian|后面|behind|500
zhong jian|中间|middle|500
pang bian|旁边|beside|500
"""

# 单字译词: 字:译词
CHAR_GLOSS = """
你:you 我:I; me 他:he; him 她:she; her 它:it 们:(plural marker) 的:of; (possessive) 了:(completed action) 是:to be 不:not 在:at; in 有:to have 和:and 这:this 那:that 个:(measure word) 人:person 大:big 小:small 中:middle 国:country
上:up; above 下:down; below 来:to come 去:to go 说:to speak 看:to look 想:to think; to want 要:to want 会:can; will 能:can 好:good 很:very 也:also 都:all 就:then 还:still 把:(object marker) 被:(passive marker) 给:to give 对:correct; to 从:from 到:to; arrive 为:for 以:by; with 可:can 么:(suffix) 吗:(question particle) 呢:(particle) 吧:(suggestion particle) 啊:(exclamation)
一:one 二:two 三:three 四:four 五:five 六:six 七:seven 八:eight 九:nine 十:ten 百:hundred 千:thousand 万:ten thousand 两:two 几:how many 多:many 少:few 年:year 月:month 日:day; sun 天:sky; day 时:time 分:minute; to divide 秒:second
爱:love 吃:to eat 喝:to drink 睡:to sleep 走:to walk 跑:to run 坐:to sit 站:to stand 开:to open 关:to close 买:to buy 卖:to sell 做:to do 用:to use 找:to look for 问:to ask 答:to answer 写:to write 读:to read 听:to listen 学:to learn 教:to teach 工:work 作:to make 玩:to play 笑:to laugh 哭:to cry 等:to wait 住:to live 死:to die 活:alive 生:to be born 知:to know 道:way 觉:to feel 记:to remember 忘:to forget 懂:to understand 帮:to help 送:to send 带:to bring 拿:to take 放:to put 进:to enter 出:to exit 回:to return 过:to pass 起:to rise 飞:to fly 换:to change 变:to change 选:to choose 请:please 谢:to thank
家:home 校:school 水:water 火:fire 山:mountain 河:river 海:sea 风:wind 雨:rain 雪:snow 云:cloud 花:flower 草:grass 树:tree 鸟:bird 鱼:fish 狗:dog 猫:cat 牛:ox 马:horse 羊:sheep 米:rice 菜:vegetable 茶:tea 酒:wine 饭:meal 面:noodles; face 肉:meat 蛋:egg 糖:sugar 汤:soup
手:hand 头:head 眼:eye 耳:ear 口:mouth 心:heart 脚:foot 身:body 脸:face 门:door 窗:window 床:bed 桌:table 车:vehicle 路:road 书:book 笔:pen 纸:paper 字:character 词:word 话:speech 语:language 文:writing 图:picture 电:electricity 网:net 机:machine 钱:money 店:shop 院:courtyard 楼:building
红:red 黄:yellow 蓝:blue 绿:green 白:white 黑:black 新:new 旧:old 长:long 短:short 高:tall; high 低:low 快:fast 慢:slow 早:early 晚:late 远:far 近:near 冷:cold 热:hot 美:beautiful 难:difficult 容:to contain 易:easy 重:heavy 轻:light 忙:busy 累:tired 饿:hungry 渴:thirsty 对:right 错:wrong 真:real 假:fake 同:same 别:other; do not
前:front 后:back 左:left 右:right 东:east 西:west 南:south 北:north 里:inside 外:outside 内:inside 间:between 边:side 旁:beside 面:surface
父:father 母:mother 爸:dad 妈:mom 哥:older brother 姐:older sister 弟:younger brother 妹:younger sister 子:child 儿:son 女:female 男:male 友:friend 师:teacher 同:same 王:king 李:Li (surname) 张:Zhang (surname) 刘:Liu (surname) 陈:Chen (surname)
事:matter 情:feeling 问:question 题:topic 意:meaning 思:thought 义:meaning 理:reason 力:strength 法:method 方:direction 式:style 主:main 要:important 点:point 次:time (occurrence) 种:kind 样:appearance 些:some 每:every 全:whole 最:most 更:more 太:too 非:not 常:often 总:always 已:already 经:pass through 再:again 又:again 才:only then 刚:just 正:just; correct 只:only 但:but 而:and yet 因:cause 所:place 如:like 果:fruit 虽:although 然:so 或:or 者:person who 当:when 还:also 并:and 且:moreover
""".strip()


def main(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    rows = []
    seen = set()
    for line in CHARS.strip().splitlines():
        syl, chars = line.split(":")
        syl = syl.strip()
        for rank, ch in enumerate(chars.split()):
            if (syl, ch) in seen:
                continue
            seen.add((syl, ch))
            rows.append((syl, ch, max(40, int(4000 / (rank + 1)))))
    for syl, ch, w in EXTRA_READINGS:
        if (syl, ch) in seen:
            continue
        seen.add((syl, ch))
        rows.append((syl, ch, int(1500 * w)))
    gloss = {}
    for line in WORDS.strip().splitlines():
        py, word, g, freq = line.split("|")
        if len(py.split()) != len(word):
            print("WARN syllable/char mismatch:", line, file=sys.stderr)
        rows.append((py, word, int(freq) * 20))
        gloss[word] = g
    # 单字译词用 "字:译词" 形式，译词里可能有空格，故按 "字:" 起始切分
    import re
    parts = re.split(r"(?:(?<=\s)|^)(\S):", CHAR_GLOSS.replace("\n", " "))
    # parts = ['', 字, 译词, 字, 译词 ...]
    for i in range(1, len(parts) - 1, 2):
        ch, g = parts[i], parts[i + 1].strip()
        if g and ch not in gloss:
            gloss[ch] = g
    with open(os.path.join(out_dir, "lexicon.tsv"), "w", encoding="utf-8") as f:
        f.write("# pinyin\tword\tfreq   (seed lexicon, hand written; run tools/build_lexicon.py for the full one)\n")
        for syl, ch, fr in rows:
            f.write(f"{syl}\t{ch}\t{fr}\n")
    with open(os.path.join(out_dir, "gloss_en.tsv"), "w", encoding="utf-8") as f:
        f.write("# word\tgloss\n")
        for w, g in gloss.items():
            f.write(f"{w}\t{g}\n")
    print(f"lexicon rows: {len(rows)}, glosses: {len(gloss)}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "Resources"))
