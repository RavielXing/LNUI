local _, GF = ...

-- Presentation only. Core owns real arrivals, unread and one sound per message.
-- Eight static images share one continuous clock, including the appearance ring
-- and crescents. Debug uses a separate instance of this class.
local Alert = {}
Alert.__index = Alert
GF.FloatMessageAlert = Alert
local ART, STYLE = GF.FLOAT_MESSAGE_ALERT_ATLAS, GF.FLOAT_MESSAGE_ALERT_STYLE
local FPS = STYLE.fps
local MOTION = GF.FLOAT_MESSAGE_MOTION
local INTRO = STYLE.introDuration
local RECEIPT_BURSTS = STYLE.bursts
local function clamp(v) return math.max(0, math.min(1, v)) end
local function ease(v) return v * v * (3 - 2 * v) end
local function mix(a,b,t) return a+(b-a)*t end
local function pulseGlowRadius(t)
 local delay,turn=STYLE.pulseGlowDelay,STYLE.pulseGlowReturnStart
 local returning=t>=turn
 local p=clamp(returning and (t-turn)/(1-turn) or (t-delay)/(turn-delay))
 -- The soft wave has its own travel: trail the stroke, widen, then gently return.
 -- Zero speed and acceleration at each join avoid a snap at launch or reversal.
 local progress=clamp(p^3*(10+p*(6*p-15)))
 if returning then return mix(STYLE.pulseGlowPeakRadius,STYLE.pulseGlowReturnRadius,progress) end
 return mix(STYLE.pulseGlowStartRadius,STYLE.pulseGlowPeakRadius,progress)
end
local function exitRetreat(self)
 if not self.exitAge then return 0 end
 return ease(clamp((self.exitAge-STYLE.exitCrescentDelay)/(self.exitDuration-STYLE.exitCrescentDelay)))
end

function Alert.New(parent, anchor)
 local self = setmetatable({ anchor=anchor, enabled=false, unread=false, active=false,
  continuous=false, age=0, alpha=0, expansion=0, layers={}, stateProgress=0 }, Alert)
 self.frame=CreateFrame("Frame",nil,parent)
 self.frame:SetAllPoints(parent);self.frame:EnableMouse(false)
 -- All rings, orbit particles and their glows share a host behind the panels.
 self.pulseHost=CreateFrame("Frame",nil,parent)
 self.pulseHost:SetAllPoints(parent);self.pulseHost:EnableMouse(false)
 self.markerHost=CreateFrame("Frame",nil,self.frame)
 self.markerHost:SetAllPoints(self.frame);self.markerHost:EnableMouse(false)
 self.frame:SetScript("OnUpdate",function(_,elapsed)self:Update(elapsed)end)
 self.frame:Hide();self.pulseHost:Hide()
 return self
end
function Alert:SetFrameLevel(level,markerLevel,pulseLevel)
 self.frame:SetFrameLevel(level)
 self.markerHost:SetFrameLevel(markerLevel or level+6)
 self.pulseHost:SetFrameLevel(pulseLevel or math.max(0,level-2))
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
 self.frame:Hide();self.pulseHost:Hide()
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
 self.frame:Show();self.pulseHost:Show();self:Render()
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
  self.exitDuration=STYLE.fadeOut
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
  local orbit=role=="crescent" or role=="particle"
  local rear=role=="pulse" or role=="rear" or orbit
  local host=role=="marker" and self.markerHost or (rear and self.pulseHost or self.frame)
  local sublevel=orbit and 3 or (role=="pulse" and 2 or 1)
  layer={texture=host:CreateTexture(nil,"ARTWORK",nil,sublevel),role=role}
  layer.texture:SetBlendMode("BLEND");self.layers[slot]=layer
 end
 local t=layer.texture
 if layer.atlas~=f[1] then t:SetTexture(atlas.texture);layer.atlas=f[1] end
 if layer.id~=id then
  t:SetTexCoord(f[2]/atlas.width,(f[2]+f[4])/atlas.width,f[3]/atlas.height,(f[3]+f[5])/atlas.height)
  layer.id=id
  layer.width=nil
 end
 local ax,ay=0.5,0.5
 if asset=="SparkGlow" then ax,ay=ART.sparkAnchor[1],ART.sparkAnchor[2]
 elseif asset=="Icon" then ay=STYLE.iconAnchorY end
 if layer.width~=w or layer.height~=h or layer.x~=x or layer.y~=y then
  -- Preserve each master's canvas and center after lossless transparent trimming.
  t:SetSize(w*f[4]/f[6]*STYLE.scale,h*f[5]/f[7]*STYLE.scale);t:ClearAllPoints()
  t:SetPoint("TOPLEFT",self.anchor,"CENTER",
   (x+w*(f[8]/f[6]-ax))*STYLE.scale,(-y+h*(ay-f[9]/f[7]))*STYLE.scale)
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

-- One geometric pose for both forms. Crossfading art must not crossfade two
-- different orbits, nor leave markers behind when the ring retreats on read.
function Alert:GetRingPose()
 local collapsed,expanded,p=STYLE.variants.Collapsed,STYLE.variants.Expanded,self.expansion
 local duration=mix(collapsed.crescentEnterDuration,expanded.crescentEnterDuration,p)
 local appear=self.entry and ease(clamp((self.age-STYLE.crescentDelay)/duration)) or 1
 local retreat=exitRetreat(self)
 local exitScale=1-STYLE.crescentExitShrink*retreat
 local radius=mix(collapsed.particleRadius,expanded.particleRadius,p)
  *(STYLE.crescentStartScale+(1-STYLE.crescentStartScale)*appear)*exitScale
 local y=mix(collapsed.crescentEnterOffset,expanded.crescentEnterOffset,p)*(1-appear)*exitScale
 local gap=mix(collapsed.markerY-collapsed.particleRadius,expanded.markerY-expanded.particleRadius,p)*exitScale
 return radius,y,appear,gap
end

function Alert:RenderVariant(prefix,weight,radius,centerY,appear,markerGap)
 local alpha=self.alpha*weight
 if alpha<=0 then
  for slot in pairs(self.layers)do if slot:sub(1,#prefix)==prefix then self:HideLayer(slot)end end
  return
 end
 local shape=STYLE.variants[prefix]
 local entering=self.entry and self.age<INTRO
 local exitBlend=self.exitAge and ease(clamp(self.exitAge/STYLE.exitBlend)) or 0
 local crescentSize=radius*STYLE.masterCanvas/shape.crescentSourceRadius
 -- ThinCrescent already contains the faint upper ring; no extra ring underneath.
 local crescentAlpha=alpha*appear
 if prefix=="Collapsed" then
  local time=math.max(0,self.age-(self.entry and INTRO or 0))
  crescentAlpha=crescentAlpha*(1-STYLE.crescentDim*(0.5-0.5*math.cos(2*math.pi*time/STYLE.breathPeriod)))
 end
 self:DrawStatic(prefix.."Crescent",shape.crescent,crescentSize,crescentSize,0,centerY,crescentAlpha,"crescent")
 local buttonSize,buttonAlpha,buttonY=1,alpha,centerY+radius+markerGap
 local receiveTime=-1
 if entering then
  local t=clamp((self.age-shape.buttonDelay/FPS)/(shape.buttonEnterFrames/FPS))
  buttonSize=ease(t);buttonAlpha=alpha*ease(t)
 elseif self.continuous or self.exitContinuous then
  local delay=shape.receiptDelay/FPS
  local cycle=shape.cycleFrames/FPS
  -- A frame-aligned modulo avoids rounding 98 frames down to frame 97 at wrap.
  local phase=(((self.continuousAge or 0)*FPS+0.000001)%(cycle*FPS))/FPS
  buttonSize=1+shape.pulseScale*markerPulse(phase)
  receiveTime=phase-delay
 end
 if self.exitAge then
  local fade=1-ease(clamp(self.exitAge/STYLE.exitMarkerDuration))
  buttonSize=buttonSize*fade;buttonAlpha=buttonAlpha*fade
 end
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
    local scale=radius/distance
    x,y=x*scale,y*scale
   else x,y=0,radius end
   y=y+centerY
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
 local radius,centerY,appear,gap=self:GetRingPose()
 local pulseTime=self.entry and clamp(self.age/INTRO) or 1
 local pulseGlow=1-ease(clamp((pulseTime-STYLE.pulseGlowFadeStart)/(1-STYLE.pulseGlowFadeStart)))
 -- One eye-centered light keeps its breathing phase through shape transitions.
 -- Raised cosine gives zero velocity at the breathing minimum and maximum.
 local wave=0.5-0.5*math.cos(2*math.pi*(self.age%STYLE.breathPeriod)/STYLE.breathPeriod)
 local breath=STYLE.breathFloor+(1-STYLE.breathFloor)*wave^STYLE.breathPower
 -- Hand over to the existing breathing phase as the outer afterglow clears.
 -- Keep a faint inner halo, and match both value and slope at the intro end.
 breath=mix(breath,STYLE.breathFloor,pulseGlow)
 local glowFade=self.exitAge and 1-ease(clamp(self.exitAge/STYLE.exitGlowDuration)) or 1
 -- Preserve the eye-centered 520 px master, including its asymmetric trim.
 -- Keep the same size in both forms: following the expanded orbit leaves a gap.
 local middleAppear=self.entry and ease(clamp((self.age-STYLE.middleGlowDelay)/STYLE.middleGlowEnterDuration)) or 1
 local middleAlpha=self.alpha*breath*STYLE.middleGlowAlpha*middleAppear*glowFade
 self:DrawStatic("MiddleGlow","MiddleGlow",STYLE.middleGlowCanvas,STYLE.middleGlowCanvas,0,0,middleAlpha,"rear")
 self:RenderVariant("Collapsed",1-self.expansion,radius,centerY,appear,gap)
 self:RenderVariant("Expanded",self.expansion,radius,centerY,appear,gap)
 local pulseAlpha=self.alpha*(self.exitAge and 1-ease(clamp(self.exitAge/STYLE.exitBlend)) or 1)
 -- SoftGlowRing is only the one-shot outer afterglow, never a steady layer.
 if self.entry and self.age<INTRO then
  -- Fast outward travel clears the eye before fading, then settles at the edge.
  local radius=mix(STYLE.pulseStartRadius,STYLE.pulseEndRadius,1-(1-pulseTime)^3)
  local size=radius*STYLE.ringCanvasPerRadius
  -- Fade the delayed soft wave in independently; preserve the inner breath handoff.
  local glowSize=pulseGlowRadius(pulseTime)*STYLE.glowCanvasPerRadius
  local glowAppear=ease(clamp((pulseTime-STYLE.pulseGlowDelay)/STYLE.pulseGlowFadeIn))
  local strokeFade=ease(clamp((pulseTime-STYLE.pulseFadeStart)/(STYLE.pulseFadeEnd-STYLE.pulseFadeStart)))
  local stroke=clamp(1-strokeFade)^STYLE.pulseStrokePower
  self:DrawStatic("pulseGlow","SoftGlowRing",glowSize,glowSize,0,0,pulseAlpha*pulseGlow*glowAppear*STYLE.pulseGlowAlpha,"pulse")
  self:DrawStatic("pulse","ThinRing",size,size,0,0,pulseAlpha*stroke,"pulse")
 else self:HideLayer("pulse");self:HideLayer("pulseGlow") end
end
function Alert:Update(elapsed)
 if not self.active or not self.enabled then return end
 elapsed=math.max(0,elapsed)
 if self.exitAge then
  self.exitAge=self.exitAge+elapsed
  self.alpha=self.exitFrom*(1-exitRetreat(self))
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
