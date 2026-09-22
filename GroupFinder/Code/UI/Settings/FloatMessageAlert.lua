local _, GF = ...

-- Presentation only. Core owns real arrivals, unread and one sound per message.
-- Static textures drive breath, markers and particles. Only the appearance ring
-- and crescents retain source sequences. Debug uses a separate instance of this class.
local Alert = {}
Alert.__index = Alert
GF.FloatMessageAlert = Alert
local ART, STYLE = GF.FLOAT_MESSAGE_ALERT_ATLAS, GF.FLOAT_MESSAGE_ALERT_STYLE
local FPS = STYLE.fps
local MOTION = GF.FLOAT_MESSAGE_MOTION
local INTRO = #ART.clips.AlertPulse / FPS
local RECEIPT_BURSTS = STYLE.bursts
local function clamp(v) return math.max(0, math.min(1, v)) end
local function ease(v) return v * v * (3 - 2 * v) end

function Alert.New(parent, anchor)
 local self = setmetatable({ anchor=anchor, enabled=false, unread=false, active=false,
  continuous=false, age=0, alpha=0, expansion=0, layers={}, stateProgress=0 }, Alert)
 self.frame=CreateFrame("Frame",nil,parent)
 self.frame:SetAllPoints(parent);self.frame:EnableMouse(false)
 self.markerHost=CreateFrame("Frame",nil,self.frame)
 self.markerHost:SetAllPoints(self.frame);self.markerHost:EnableMouse(false)
 self.frame:SetScript("OnUpdate",function(_,elapsed)self:Update(elapsed)end)
 self.frame:Hide()
 return self
end
function Alert:SetFrameLevel(level,markerLevel)
 self.frame:SetFrameLevel(level)
 self.markerHost:SetFrameLevel(markerLevel or level+6)
end
function Alert:SetExpansion(progress)
 progress=clamp(progress)
 if self.expansion==progress then return end
 self.expansion=progress
 if self.active then self:Render() end
end
function Alert:GetPhase()
 if not self.active then return "idle" end
 if self.exitAge then return "exit" end
 if self.entry and self.age<INTRO then return "enter" end
 return self.continuous and "continuous" or "reminder"
end
function Alert:Reset()
 self.active,self.entry,self.exitAge,self.continuousAge=false,false,nil,nil
 self.age,self.alpha,self.stateProgress=0,0,self.continuous and 1 or 0
 self.exitContinuous=nil
 for _,layer in pairs(self.layers)do
  layer.texture:Hide();layer.texture:SetTexture(nil);layer.id,layer.atlas=nil,nil
 end
 self.frame:Hide()
end
function Alert:SetEnabled(enabled)
 enabled=enabled==true
 if self.enabled==enabled then return end
 self.enabled=enabled
 if not enabled then self:Reset() elseif self.unread then self:Start(false) end
end
function Alert:Start(entrance)
 self.active,self.entry,self.age,self.exitAge=true,entrance,0,nil
 self.exitContinuous=nil
 self.continuousAge=self.continuous and 0 or nil
 self.frame:Show();self:Render()
end
function Alert:SetUnread(unread)
 unread=unread==true
 if self.unread==unread then return end
 self.unread=unread
 if unread then
  self.continuous,self.stateProgress=false,0
  if self.enabled then self:Start(false) end
 elseif self.active then
  if self.alpha<=0 then self.continuous=false;self:Reset();return end
  -- Keep both shape clocks frozen, including the currently invisible shape.
  -- Opening the launcher while reading can therefore still blend both poses.
  self.exitContinuous=self.continuous
  self.exitAge,self.exitFrom=0,self.alpha
  self.exitDuration=math.max(STYLE.fadeOut,
   #ART.clips.CollapsedCrescentEnter/FPS,#ART.clips.ExpandedCrescentEnter/FPS)
  self.continuous=false
  self:Render()
 else self.continuous,self.stateProgress=false,0 end
end
function Alert:OnMessage()
 local continuing=self.unread
 self.unread=true
 if not continuing then
  self.continuous,self.stateProgress=false,0
  if self.enabled then self:Start(true) end
  return
 end
 if not self.continuous then
  self.continuous=true
  -- Early second arrival upgrades after appearance, without restarting it.
  self.continuousAge=0
 end
 if self.enabled and not self.active then self:Start(false) end
 -- Further arrivals never rewind the continuous loop; Core plays their sound.
end

function Alert:Draw(slot,clipName,seconds,alpha,loop,hold,offsetX,offsetY,reverse,mirror)
 local clip=ART.clips[clipName]
 local index=math.floor((seconds or -1)*FPS+0.000001)
 local layer=self.layers[slot]
 if alpha<=0 or index<0 or not loop and not hold and index>=#clip then
  if layer then layer.texture:Hide() end
  return
 end
 index=loop and index % #clip or math.min(index,#clip-1)
 if reverse then index=#clip-1-index end
 local id=clip[index+1]
 local f=ART.frames[id];local atlas=ART.atlases[f[1]]
 if not layer then
  layer={texture=self.frame:CreateTexture(nil,"ARTWORK",nil,slot=="pulse" and 2 or 1)}
  layer.texture:SetBlendMode("BLEND");self.layers[slot]=layer
 end
 local texture=layer.texture
 if layer.atlas~=f[1] then texture:SetTexture(atlas.texture);layer.atlas=f[1] end
 if layer.id~=id or layer.mirror~=mirror or layer.offsetX~=offsetX or layer.offsetY~=offsetY then
  local scale,half=STYLE.scale,STYLE.canvasSize/2
  local left,right=f[2]/atlas.width,(f[2]+f[4])/atlas.width
  local x=f[8]+(offsetX or 0)
  if mirror then left,right=right,left;x=STYLE.canvasSize-x-f[4] end
  texture:SetTexCoord(left,right,
   f[3]/atlas.height,(f[3]+f[5])/atlas.height)
  texture:SetSize(f[4]*scale,f[5]*scale);texture:ClearAllPoints()
  texture:SetPoint("TOPLEFT",self.anchor,"CENTER",
   (-half+x)*scale,(half-f[9]-(offsetY or 0))*scale)
  layer.id,layer.mirror,layer.offsetX,layer.offsetY=id,mirror,offsetX,offsetY
 end
 texture:SetAlpha(alpha);texture:Show()
end
function Alert:HideLayer(slot)
 local layer=self.layers[slot]
 if layer then layer.texture:Hide() end
end
-- Static art with continuous transforms. Coordinates use the 130 px eye canvas.
function Alert:DrawStatic(slot,asset,w,h,x,y,alpha,role)
 if alpha<=0 or w<=0 or h<=0 then self:HideLayer(slot);return end
 local id=ART.static[asset];local f=ART.frames[id];local atlas=ART.atlases[f[1]]
 local layer=self.layers[slot]
 if not layer then
  local host=role=="marker" and self.markerHost or self.frame
  layer={texture=host:CreateTexture(nil,"ARTWORK",nil,1),role=role}
  layer.texture:SetBlendMode("BLEND");self.layers[slot]=layer
 end
 local t=layer.texture
 if layer.atlas~=f[1] then t:SetTexture(atlas.texture);layer.atlas=f[1] end
 if layer.id~=id then
  t:SetTexCoord(f[2]/atlas.width,(f[2]+f[4])/atlas.width,f[3]/atlas.height,(f[3]+f[5])/atlas.height)
  layer.id=id
 end
 local ax,ay=0.5,0.5
 if asset=="SparkGlow" then ax,ay=ART.sparkAnchor[1],ART.sparkAnchor[2] end
 if layer.width~=w or layer.height~=h or layer.x~=x or layer.y~=y then
  t:SetSize(w*STYLE.scale,h*STYLE.scale);t:ClearAllPoints()
  t:SetPoint("TOPLEFT",self.anchor,"CENTER",(x-w*ax)*STYLE.scale,(-y+h*ay)*STYLE.scale)
  layer.width,layer.height,layer.x,layer.y=w,h,x,y
 end
 t:SetAlpha(alpha);t:Show()
end

local function interpolate(a,b,previous,following,p,column)
 local m0=(b[column]-previous[column])/(b[1]-previous[1])*(b[1]-a[1])
 local m1=(following[column]-a[column])/(following[1]-a[1])*(b[1]-a[1])
 return (2*p^3-3*p^2+1)*a[column]+(p^3-2*p^2+p)*m0+(-2*p^3+3*p^2)*b[column]+(p^3-p^2)*m1
end
local function trajectory(keys,time)
 if time<0 or time>=keys[#keys][1]+1/FPS then return nil end
 if time>=keys[#keys][1] then
  local k=keys[#keys];return k[2],k[3],k[4]*(1-(time-k[1])*FPS)
 end
 for i=1,#keys-1 do
  local a,b=keys[i],keys[i+1]
  if time>=a[1] and time<b[1] then
   local p=(time-a[1])/(b[1]-a[1]);local prev=keys[math.max(1,i-1)];local next=keys[math.min(#keys,i+2)]
   -- Hermite interpolation follows measured source positions at any game FPS.
   return interpolate(a,b,prev,next,p,2),interpolate(a,b,prev,next,p,3),clamp(interpolate(a,b,prev,next,p,4))
  end
 end
end

local function markerPulse(time)
 local keys=STYLE.markerPulse
 for i=1,#keys-1 do
  local a,b=keys[i],keys[i+1]
  if time>=a[1] and time<b[1] then
   return a[2]+(b[2]-a[2])*ease((time-a[1])/(b[1]-a[1]))
  end
 end
 return 0
end

function Alert:RenderVariant(prefix,weight)
 local alpha=self.alpha*weight
 if alpha<=0 then
  for slot in pairs(self.layers)do if slot:sub(1,#prefix)==prefix then self:HideLayer(slot)end end
  return
 end
 local shape=STYLE.variants[prefix]
 local entering=self.entry and self.age<INTRO
 local expanded=prefix=="Expanded"
 local breathTime=self.age-(self.entry and shape.breathDelay/FPS or 0)
 local breath=STYLE.breathFloor+(1-STYLE.breathFloor)*math.sin(math.pi*((math.max(0,breathTime)%STYLE.breathPeriod)/STYLE.breathPeriod))^STYLE.breathPower
 self:DrawStatic(prefix.."Breathe",prefix.."Glow",STYLE.canvasSize,STYLE.canvasSize,0,shape.glowOffsetY,alpha*breath)
 local exitBlend=self.exitAge and ease(clamp(self.exitAge/STYLE.exitBlend)) or 0
 local crescentAlpha=alpha*(1-exitBlend)
 if entering then
  self:Draw(prefix.."Crescent",prefix.."CrescentEnter",self.age-STYLE.crescentDelay,crescentAlpha,false,true)
 elseif expanded then
  self:Draw(prefix.."Crescent",prefix.."CrescentEnter",100,crescentAlpha,false,true)
 else
  self:Draw(prefix.."Crescent","CollapsedCrescentLoop",self.age-(self.entry and INTRO or 0),crescentAlpha,true)
 end
 if self.exitAge then
  self:Draw(prefix.."CrescentExit",prefix.."CrescentEnter",self.exitAge,alpha*exitBlend,false,true,nil,nil,true)
 else self:HideLayer(prefix.."CrescentExit")end
 local buttonSize,buttonAlpha,buttonY=1,alpha,shape.markerY
 local receiveTime=-1
 if entering then
  local t=clamp((self.age-shape.buttonDelay/FPS)/(shape.buttonEnterFrames/FPS))
  buttonSize=ease(t);buttonAlpha=alpha*ease(t)
  buttonY=buttonY-shape.enterOffset*(1-ease(t))
 elseif self.continuous or self.exitContinuous then
  local delay=shape.receiptDelay/FPS
  local cycle=shape.cycleFrames/FPS
  -- A frame-aligned modulo avoids rounding 98 frames down to frame 97 at wrap.
  local phase=(((self.continuousAge or 0)*FPS+0.000001)%(cycle*FPS))/FPS
  buttonSize=1+shape.pulseScale*markerPulse(phase)
  receiveTime=phase-delay
 end
 if self.exitAge then buttonSize=buttonSize*(1-ease(clamp(self.exitAge/self.exitDuration)))end
 local buttonWidth,buttonHeight=shape.markerWidth*buttonSize,shape.markerHeight*buttonSize
 self:DrawStatic(prefix.."Button",shape.marker,buttonWidth,buttonHeight,0,buttonY,buttonAlpha,"marker")
 for _,burst in ipairs(RECEIPT_BURSTS)do
  local x,y,opacity=trajectory(MOTION[prefix],receiveTime-burst.delay/FPS)
  local slot=prefix..burst.slot
  if x then
   -- Source glow centroids supply angular timing, not the orbit radius.
   -- Project after interpolation so motion between keys stays on the gold line.
   local distance=math.sqrt(x*x+y*y)
   if distance>0 then
    local scale=shape.particleRadius/distance
    x,y=x*scale,y*scale
   else x,y=0,shape.particleRadius end
   if burst.mirror then x=-x end
   local strength=alpha*self.stateProgress*opacity*(1-exitBlend)
   local size=STYLE.particleMinSize+STYLE.particleGrowth*opacity
   local glowScale=STYLE.sparkMinScale+STYLE.sparkGrowth*opacity
   self:DrawStatic(slot.."Glow","SparkGlow",STYLE.sparkWidth*glowScale,STYLE.sparkHeight*glowScale,x,y,strength*STYLE.sparkAlpha,"particle")
   self:DrawStatic(slot,"Point",size,size*STYLE.particleAspect,x,y,strength,"particle")
  else self:HideLayer(slot);self:HideLayer(slot.."Glow") end
 end
end
function Alert:Render()
 if not self.active then return end
 self:RenderVariant("Collapsed",1-self.expansion);self:RenderVariant("Expanded",self.expansion)
 local pulseAlpha=self.alpha*(self.exitAge and 1-ease(clamp(self.exitAge/STYLE.exitBlend)) or 1)
 -- One appearance pulse per unread episode. It never belongs to either loop.
 self:Draw("pulse","AlertPulse",self.entry and self.age or -1,pulseAlpha,false,false)
end
function Alert:Update(elapsed)
 if not self.active or not self.enabled then return end
 elapsed=math.max(0,elapsed)
 if self.exitAge then
  self.exitAge=self.exitAge+elapsed
  self.alpha=self.exitFrom*(1-ease(clamp(self.exitAge/self.exitDuration)))
  if self.exitAge>=self.exitDuration then self:Reset();return end
 else
  local previous=self.age;self.age=self.age+elapsed
  self.alpha=math.min(1,self.alpha+elapsed/STYLE.fadeIn)
  if self.continuous then
   local activeDelta=elapsed
   if self.entry then activeDelta=math.max(0,self.age-math.max(previous,INTRO)) end
   self.continuousAge=(self.continuousAge or 0)+activeDelta
   self.stateProgress=ease(clamp((self.continuousAge or 0)/STYLE.stateTransition))
  end
 end
 self:Render()
end
