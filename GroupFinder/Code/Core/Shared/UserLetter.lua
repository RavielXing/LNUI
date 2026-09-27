local _, GF = ...

-- This is a signed letter supplied by the author. Keep the original Chinese
-- copy in every UI locale; it is independent of the About changelog.
GF.UserLetter = {
	-- The letter edition/acknowledgment is independent of the addon release.
	VERSION = "3.0.0",
	TITLE = "致魔兽集合石用户的一封信",
	READ_LABEL = "已阅",
	BLOCKS = {
		{ text = "艾泽拉斯的勇士：" },
		{ text = "|cffffd100这次想给你写封信，聊聊 GroupFinder 即将翻开的新一页，也聊聊我为什么想做这次尝试。|r" },
		{ text = "不过在这之前，还是想先认真地对你说一声：|cffffd100谢谢|r。" },
		{ text = "谢谢你选择魔兽集合石（GroupFinder），陪着它一点点变成今天的模样。从上线至今，我收到了许多玩家的反馈和建议，有的是一个按钮的位置，有的是某项功能用起来不够顺手，也有不少让我眼前一亮的新想法。" },
		{ text = "这些声音，我都很珍惜。对我来说，插件不是写完代码、发布出去就结束了。你用得顺不顺手，能不能更容易找到队伍，才是它值得继续做下去的理由。" },
		{ text = "我一直希望，这块集合石能让你在组队时少一点折腾，在冒险中多一点尽兴。" },
		{ text = "随着《魔兽世界》12.1 版本实装，赛季团队副本为大家带来了新的冒险节奏。从孢陨幽境到潮缚石窟，短平快的单首领团本，让更多玩家能够轻装上阵，体验团队协作、一起击败强敌的乐趣。Roll 币机制的加入，也让心仪的装备多了一份盼头。" },
		{ text = "玩法变了，我也开始琢磨：我们的组队方式，是不是也能变一变？" },
		{ text = "你可能也有过这样的经历：明明只是想找个团打一次副本，却花了不少时间刷新列表、递交申请，再等一个不确定的回复。好不容易遇到一位指挥清晰、相处舒服的团长，下次想再跟他的团，却又找不到了。" },
		{ text = "而在另一边，也许正有一位团长，为迟迟补不齐的那个位置发愁。" },
		{ text = "既然两边都在找，能不能让彼此更容易看见对方？" },
		{ text = "带着这个念头，我在 GroupFinder 3.0.0 中加入了「|cffffd100赛季团本|r」模式，也带来了三项新功能：|cffffd100团本求组|r、|cffffd100求组广场|r、|cffffd100星标团长|r。" },
		{ heading = true, text = "◆「团本求组」想帮你省下的，是守着列表等待的时间。" },
		{ text = "你可以把自己的职业、战力和求组需求发布到「求组广场」，让正在招募的团长看见你，主动来联系你。" },
		{ text = "发布之后，就不用一直盯着队伍列表了。你可以去做做日常、打理家宅，或者在艾泽拉斯四处转转。除了继续主动寻找合适的队伍，也给合适的团队一个找到你的机会。" },
		{ text = "我希望，你打开游戏后的时间，能更多地花在自己想做的事情上，而不是反复刷新、等待回复。" },
		{ heading = true, text = "◆「求组广场」则是想给正在组人的你，多一个选择。" },
		{ text = "无论你准备从零组建一支团队，还是打到一半需要临时补位，都可以去广场看看。那里会展示发布了求组意向的玩家信息，你可以根据职业、战力和需求，主动联系适合当前团队的队友。" },
		{ text = "不必只等着申请列表里出现合适的人，也可以自己去找一找。" },
		{ text = "也许你缺的那位队友，正好也在等一个像你这样的团长。这个广场想做的，就是让你们少错过一次。" },
		{ heading = true, text = "◆「星标团长」想留下的，则是一次愉快合作之后的那份默契。" },
		{ text = "遇到一位指挥清晰、待人友善、节奏合拍的团长，打完之后，难免会想一句：“下次还跟他的团。”" },
		{ text = "现在，你可以把他标记为星标。下次找团时，通过星标筛选，就能更快找到他正在招募的队伍，不必再凭着模糊的印象回忆名字、翻找列表。" },
		{ text = "一次打得舒服的团，不一定非要在散团时就画上句号。我希望，这份默契能被留下来，成为下一次并肩出发的理由。" },
		{ text = "说到这里，也想跟你坦白：|cffffd100这次更新，不只是一次功能迭代，更是我对组队方式的一场实验|r。" },
		{ text = "过去，我们习惯了“刷列表、递申请、等回复”。这一次，我想试着让“玩家找队伍”之外，也多一条“团队找玩家”的路。" },
		{ text = "但多了一项功能，不代表问题就一定解决了。「求组广场」到底能不能减少等待，团长找人是否方便，玩家发布意向之后能否得到回应，都需要在实际使用中慢慢检验。" },
		{ text = "所以，比起现在就说它有多好，我更想听听你用过之后的感受。" },
		{ text = "哪里不顺手，哪些信息不够清楚，哪一步让你觉得麻烦，都欢迎告诉我。它还需要打磨，而你的使用体验，会帮我判断接下来该往哪里改。" },
		{ text = "赛季团本只是这场实验的起点。如果这套方式确实能帮到大家，我也会把它逐步带到「|cffffd100大秘境|r」模式中。无论是临时找一趟钥石车队，还是寻找长期冲层的固定搭子，我都希望你能更容易遇见合拍的人。" },
		{ text = "|cffffd100毕竟，找到队伍只是第一步。找到愿意一起再打一场的队友，才更让人高兴。|r" },
		{ text = "还有一件事，需要在这里跟你说清楚。" },
		{ text = "「团本求组」与「求组广场」依托 GroupFinder |cffffd100自建的通讯机制运行|r，并不是游戏内置的官方预组队列表。广场中的求组信息，来自插件用户的自主发布与共享。" },
		{ text = "这意味着，参与的玩家越多，广场里可供选择的信息就越丰富；使用它的团长越多，发布求组的你，被看见、被联系、被邀请的机会也就越多。" },
		{ text = "|cffffd100我能做的是把功能继续打磨好，但这座广场能不能慢慢热闹起来，还需要大家一起参与。|r" },
		{ text = "如果 GroupFinder 曾经帮你找到过合适的队伍，或者这次的新功能让你觉得值得一试，欢迎把它介绍给公会里的伙伴、固定队的战友，也介绍给那个经常和你一起吐槽“组队怎么这么难”的朋友。" },
		{ text = "你的一次分享，也许就能让一位玩家少等一会儿，让一支团队更早补齐最后一个位置。" },
		{ text = "当然，你愿意打开它试一试，认真告诉我哪里好用、哪里还不好用，对我来说，也是一份很实在的支持。" },
		{ text = "|cffffd100写到最后，还是想再说一声谢谢。|r" },
		{ text = "谢谢你愿意使用 GroupFinder，谢谢你提出的建议，也谢谢你愿意给这次新尝试一个机会。" },
		{ text = "我会继续把这块集合石打磨下去。希望它不只是帮你找到一支能进的队伍，也能帮你遇见一些聊得来、打得合拍、下次还想一起出发的人。" },
		{ text = "愿每一次集结，都能遇见合拍的战友；\n愿每一次出征，都有值得托付的伙伴。" },
		{ text = "艾泽拉斯见。" },
		{ signature = true, text = "草东 · 白银之手\n魔兽世界收获节，书" },
	},
}
local Letter = GF.UserLetter

function Letter:IsUnread()
	-- 直接禁用首次弹出的用户信，lnui
	return false
end

function Letter:OnLogin()
	if self._loginHandled then return end
	self._loginHandled = true
	self._pending = self:IsUnread()
end

function Letter:OnEnteringWorld()
	self._worldReady = true
	return self:TryShow()
end

function Letter:TryShow()
	if not self._pending or not self._worldReady then return false end
	if not self:IsUnread() then
		self._pending = false
		return false
	end
	if InCombatLockdown and InCombatLockdown() then return false end
	local dialog = GF.UserLetterDialog
	if dialog and dialog.Show and dialog:Show() then
		-- X/Esc dismisses only this session; reading is an explicit action.
		self._pending = false
		return true
	end
	return false
end

function Letter:MarkRead()
	local db = GF.GetDB and GF.GetDB()
	if type(db) ~= "table" then return false end
	db.userLetterReadVersion = self.VERSION
	self._pending = false
	return true
end
