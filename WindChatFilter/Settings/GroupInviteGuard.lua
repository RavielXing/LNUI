local W, F, L, P = unpack(select(2, ...))

P.groupInviteGuard = {
	enabled = false,--lnui
	displayMessageAfterRejecting = true,
	allowWhisperedTarget = true,
	smartMode = true,
	muteAlreadyInGroupSound = false,--lnui
	onlyFriendsOrGuildMembers = false,
	chatFilterMode = false,
}