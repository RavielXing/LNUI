function Auctionator.Utilities.Message(message)
  print(
    LIGHTBLUE_FONT_COLOR:WrapTextInColorCode(LOCALE_zhCN and "拍卖助手: " or "拍賣助手: ")--lnui
    .. message
  )
end
