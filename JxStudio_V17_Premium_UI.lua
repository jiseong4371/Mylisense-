-- Jx.studio V17 | Miku texture ID fix and configurable aim activation.
-- LocalScript: StarterPlayerScripts. Uses standard Roblox APIs only.
-- High DisplayOrder draws over game ScreenGuis, but cannot override the built-in ESC/CoreGui menu.
local Players = game:GetService('Players')
local RS = game:GetService('RunService')
local Lighting = game:GetService('Lighting')
local UIS = game:GetService('UserInputService')
local CollectionService = game:GetService('CollectionService')
local player = Players.LocalPlayer
-- This build targets NPCs/models tagged TrainingTarget in your own experience.
local MOBILE = UIS.TouchEnabled and not UIS.KeyboardEnabled
local mobileTriggerHeld = false
local pg = player:WaitForChild('PlayerGui')
local sharedEnv = _G
if type(sharedEnv.JxStudioStop)=='function' then pcall(sharedEnv.JxStudioStop) end
local old = pg:FindFirstChild('JxStudioV6')
if old then old:Destroy() end
local oldBlur = Lighting:FindFirstChild('JxStudioV6Blur')
if oldBlur then oldBlur:Destroy() end
local alive, enabled, minimized, loading = true, false, false, true
local connections, visuals = {}, {}
local options = {
 Skeleton=false, Box2D=false, Box3D=false, HeadRing=false, Health=false,
 Names=false, Distance=false, Weapon=false, Tracers=false, PartyHat=false,
 Blur=true, Teammates=true, Watermark=true, LineWeight=1, MaxDistance=2000,
 AimEnabled=false, AimAlways=false, AimHoldKey=Enum.UserInputType.MouseButton1, Aim360=false, Triggerbot=false, AimFov=140, TriggerFov=36, TriggerDelay=.015, AimPart="Head", AimSmooth=15, AimFovShow=true,
 NoRecoil=false,NoSpread=false,NoSway=false,Bhop=false,Speed=false,SpeedValue=24,Fly=false,FlySpeed=32,Noclip=false,
 Skin=false,Model=false,Crosshair=false,Chams=false,Spinbot=false,SpinSpeed=180,Language="English",
}
local ACCENT=Color3.fromRGB(68,213,238)
local C={bg=Color3.fromRGB(10,13,23),surface=Color3.fromRGB(19,24,39),
 card=Color3.fromRGB(28,34,52), stroke=Color3.fromRGB(53,64,88),
 text=Color3.fromRGB(241,246,255),muted=Color3.fromRGB(143,154,180),
 green=Color3.fromRGB(72,237,137), red=Color3.fromRGB(255,78,98),
 white=Color3.fromRGB(255,255,255)}
local function accent() return ACCENT end
local function mk(class,parent,props)
 local x=Instance.new(class)
 for k,v in pairs(props or {}) do x[k]=v end
 x.Parent=parent; return x
end
local function round(x,r) mk('UICorner',x,{CornerRadius=UDim.new(0,r)}); return x end
local function stroke(x,color,width) return mk('UIStroke',x,{Color=color,Thickness=width or 1}) end
local function label(parent,text,size,color,props)
 local p={Text=text,TextSize=size,TextColor3=color,Font=Enum.Font.Gotham,
 BackgroundTransparency=1,BorderSizePixel=0,TextXAlignment=Enum.TextXAlignment.Left}
 for k,v in pairs(props or {}) do p[k]=v end
 return mk('TextLabel',parent,p)
end
local function btn(parent,text,props)
 local p={Text=text,TextSize=12,TextColor3=C.text,Font=Enum.Font.GothamBold,
 BackgroundColor3=C.card,BorderSizePixel=0,AutoButtonColor=false}
 for k,v in pairs(props or {}) do p[k]=v end
 return round(mk('TextButton',parent,p),9)
end
local gui=mk('ScreenGui',pg,{Name='JxStudioV6',ResetOnSpawn=false,
 IgnoreGuiInset=true,DisplayOrder=10000,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local overlay=mk('Frame',gui,{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=1})
local blur=mk('BlurEffect',Lighting,{Name='JxStudioV6Blur',Size=0,Enabled=true})
local function blurState() blur.Size=(alive and options.Blur and (loading or not minimized)) and 15 or 0 end
blurState()
-- UI-only soft neon effect: two cached halo layers and a crisp 1px center.
-- The effect is enabled only for skeleton and 2D/3D box lines.
local neonLines=setmetatable({},{__mode='k'})
local function line(parent,color,neon)
 local halos
 if neon then
  halos={}
  for i=1,2 do
   halos[i]=mk('Frame',parent,{BackgroundColor3=color,
    BackgroundTransparency=(i==1 and .94 or .82),BorderSizePixel=0,
    AnchorPoint=Vector2.new(.5,.5),Visible=false,ZIndex=(i==1 and 1 or 2)})
  end
 end
 local core=mk('Frame',parent,{BackgroundColor3=color,BorderSizePixel=0,
  AnchorPoint=Vector2.new(.5,.5),Visible=false,ZIndex=3})
 if halos then neonLines[core]=halos end
 return core
end
local function draw(l,a,b,show)
 local halos=neonLines[l]
 if not show or not a or not b then
  l.Visible=false
  if halos then for _,h in ipairs(halos) do h.Visible=false end end
  return
 end
 local d=b-a
 if d.Magnitude<0.5 then
  l.Visible=false
  if halos then for _,h in ipairs(halos) do h.Visible=false end end
  return
 end
 local midpoint=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
 local rotation=math.deg(math.atan2(d.Y,d.X))
 local weight=options.LineWeight
 -- Neon lines remain slender; the faint outer layers create the glow.
 if halos then weight=math.min(weight,2) end
 l.Visible=true
 l.Position=midpoint
 l.Size=UDim2.fromOffset(d.Magnitude,weight)
 l.Rotation=rotation
 if halos then
  for i,h in ipairs(halos) do
   h.Visible=true
   h.BackgroundColor3=l.BackgroundColor3
   h.Position=midpoint
   h.Rotation=rotation
   h.Size=UDim2.fromOffset(d.Magnitude,weight+(i==1 and 5 or 2))
  end
 end
end
local function project(cam,v)
 local p=cam:WorldToViewportPoint(v)
 if p.Z<=0.05 then return nil end
 return Vector2.new(p.X,p.Y)
end
-- Stable anatomical points. Motor6D names differ in custom rigs, so use
-- actual body part locations and oriented endpoints with R6/R15 fallbacks.
local bonesR15={
 {'Head','Neck'},{'Neck','Waist'},{'Waist','Pelvis'},
 {'Neck','LeftShoulder'},{'LeftShoulder','LeftElbow'},{'LeftElbow','LeftWrist'},
 {'Neck','RightShoulder'},{'RightShoulder','RightElbow'},{'RightElbow','RightWrist'},
 {'Pelvis','LeftHip'},{'LeftHip','LeftKnee'},{'LeftKnee','LeftAnkle'},
 {'Pelvis','RightHip'},{'RightHip','RightKnee'},{'RightKnee','RightAnkle'}}
local bonesR6={
 {'Head','Neck'},{'Neck','Waist'},
 {'Neck','LeftShoulder'},{'LeftShoulder','LeftHand'},
 {'Neck','RightShoulder'},{'RightShoulder','RightHand'},
 {'Waist','LeftHip'},{'LeftHip','LeftFoot'},
 {'Waist','RightHip'},{'RightHip','RightFoot'}}
local function skeletonPoints(character,hum)
 local points={}
 local function part(name) return character:FindFirstChild(name) end
 local function at(name,y)
  local p=part(name)
  if p and p:IsA('BasePart') then
   return p.Position + p.CFrame.UpVector * (p.Size.Y * (y or 0))
  end
  return nil
 end
 local head=part('Head')
 local upper=part('UpperTorso') or part('Torso')
 local lower=part('LowerTorso') or part('Torso')
 points.Head=head and head.Position
 points.Neck=upper and at(upper.Name,.40)
 points.Waist=lower and lower.Position
 points.Pelvis=lower and at(lower.Name,-.32)
 local isR6=(part('Torso')~=nil and part('UpperTorso')==nil)
 if isR6 then
  points.LeftShoulder=at('Left Arm',.40)
  points.RightShoulder=at('Right Arm',.40)
  points.LeftHand=at('Left Arm',-.45)
  points.RightHand=at('Right Arm',-.45)
  points.LeftHip=at('Left Leg',.42)
  points.RightHip=at('Right Leg',.42)
  points.LeftFoot=at('Left Leg',-.47)
  points.RightFoot=at('Right Leg',-.47)
 else
  for _,side in ipairs({'Left','Right'}) do
   points[side..'Shoulder']=at(side..'UpperArm',.40)
   points[side..'Elbow']=at(side..'LowerArm',.40) or at(side..'UpperArm',-.45)
   points[side..'Wrist']=at(side..'Hand',0) or at(side..'LowerArm',-.45)
   points[side..'Hip']=at(side..'UpperLeg',.42)
   points[side..'Knee']=at(side..'LowerLeg',.42) or at(side..'UpperLeg',-.45)
   points[side..'Ankle']=at(side..'Foot',0) or at(side..'LowerLeg',-.45)
  end
 end
 return points,isR6 and bonesR6 or bonesR15
end
local boxEdges={{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}
local function build(p)
 local holder=mk('Frame',overlay,{Name='Debug_'..p.Name,BackgroundTransparency=1,
 Size=UDim2.fromScale(1,1),Visible=false})
 local v={holder=holder,skeleton={},box2={},box3={},hat={}}
 for i=1,22 do v.skeleton[i]=line(holder,C.white,true) end
 for i=1,4 do v.box2[i]=line(holder,accent(),true) end
 for i=1,12 do v.box3[i]=line(holder,accent(),true) end
 for i=1,3 do v.hat[i]=line(holder,accent()) end
 -- Reusable rainbow scanlines fill the triangular party hat (no external drawing).
 v.hatFill={}
 for i=1,30 do
  local strip=line(holder,C.white)
  strip.ZIndex=3
  strip.Size=UDim2.fromOffset(0,2)
  local hue=(i-1)/30
  mk('UIGradient',strip,{Color=ColorSequence.new({
   ColorSequenceKeypoint.new(0,Color3.fromHSV(hue,1,1)),
   ColorSequenceKeypoint.new(.5,Color3.fromHSV((hue+.22)%1,1,1)),
   ColorSequenceKeypoint.new(1,Color3.fromHSV((hue+.43)%1,1,1))})})
  v.hatFill[i]=strip
 end
 v.tracer=line(holder,accent())
 v.ring=round(mk('Frame',holder,{BackgroundTransparency=1,Visible=false,
 AnchorPoint=Vector2.new(.5,.5),ZIndex=5}),999)
 stroke(v.ring,C.white,2)
 v.hp=round(mk('Frame',holder,{BackgroundColor3=C.bg,BorderSizePixel=0,
 Visible=false,ZIndex=4}),3)
 v.fill=round(mk('Frame',v.hp,{BackgroundColor3=C.green,BorderSizePixel=0,
 AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.fromScale(1,1)}),2)
 local function hud()
  return label(holder,'',11,C.text,{Visible=false,ZIndex=6,
   AnchorPoint=Vector2.new(.5,0),TextXAlignment=Enum.TextXAlignment.Center,
   TextStrokeTransparency=.2,TextStrokeColor3=C.bg})
 end
 v.name=hud();v.dist=hud();v.weapon=hud()
 visuals[p]=v;return v
end
local function clear()
 for p,v in pairs(visuals) do v.holder:Destroy();visuals[p]=nil end
end
-- Project body corners. A single part behind the camera must not suppress
-- head markers, skeletons, or the rest of the player's overlays.
local function bodyBounds(character,cam)
 local root=character:FindFirstChild('HumanoidRootPart')
 if not root then return nil end
 local minX,minY,minZ=math.huge,math.huge,math.huge
 local maxX,maxY,maxZ=-math.huge,-math.huge,-math.huge
 local left,top,right,bottom=math.huge,math.huge,-math.huge,-math.huge
 local count,front=0,0
 for _,part in ipairs(character:GetChildren()) do
  if part:IsA('BasePart') and part~=root and part.Transparency<1 then
   count=count+1
   local half=part.Size*.5
   for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
    local world=part.CFrame:PointToWorldSpace(Vector3.new(x*half.X,y*half.Y,z*half.Z))
    local rel=root.CFrame:PointToObjectSpace(world)
    minX=math.min(minX,rel.X);maxX=math.max(maxX,rel.X)
    minY=math.min(minY,rel.Y);maxY=math.max(maxY,rel.Y)
    minZ=math.min(minZ,rel.Z);maxZ=math.max(maxZ,rel.Z)
    local q=project(cam,world)
    if q then
     front=front+1
     left=math.min(left,q.X);right=math.max(right,q.X)
     top=math.min(top,q.Y);bottom=math.max(bottom,q.Y)
    end
   end end end
  end
 end
 if count==0 or front==0 then return nil end
 local coords={{minX,minY,minZ},{maxX,minY,minZ},{maxX,maxY,minZ},{minX,maxY,minZ},
  {minX,minY,maxZ},{maxX,minY,maxZ},{maxX,maxY,maxZ},{minX,maxY,maxZ}}
 local corners={}
 for i,t in ipairs(coords) do
  corners[i]=project(cam,root.CFrame:PointToWorldSpace(Vector3.new(t[1],t[2],t[3])))
 end
 return left,top,right,bottom,corners
end

local function hide(lines) for _,l in ipairs(lines) do l.Visible=false end end
local function update(p,v,cam,view)
 local ch=p.Character
 local hum=ch and ch:FindFirstChildOfClass('Humanoid')
 local root=ch and ch:FindFirstChild('HumanoidRootPart')
 local head=ch and ch:FindFirstChild('Head')
 if not (hum and root and head) or hum.Health<=0 then v.holder.Visible=false;return end
 if not options.Teammates and player.Team~=nil and p.Team==player.Team then v.holder.Visible=false;return end
 local myCh=player.Character;local myRoot=myCh and myCh:FindFirstChild('HumanoidRootPart')
 local distance
 if myRoot then distance=(myRoot.Position-root.Position).Magnitude
 else distance=(cam.CFrame.Position-root.Position).Magnitude end
 if distance>options.MaxDistance then v.holder.Visible=false;return end
  local x1,y1,x2,y2,corners=bodyBounds(ch,cam)
 if not x1 then
  -- Fallback to root projection if a partly loaded/occluded rig has no projected body bounds.
  local center=project(cam,root.Position)
  if not center then v.holder.Visible=false;return end
  local scale=math.clamp(550/math.max((cam.CFrame.Position-root.Position).Magnitude,1),8,90)
  x1,y1,x2,y2=center.X-scale*.5,center.Y-scale*1.7,center.X+scale*.5,center.Y+scale*1.7
  corners={}
 end
 if x2<0 or x1>view.X or y2<0 or y1>view.Y then v.holder.Visible=false;return end
 v.holder.Visible=true
 local a,b,c,d=Vector2.new(x1,y1),Vector2.new(x2,y1),Vector2.new(x2,y2),Vector2.new(x1,y2)
 local xy={{a,b},{b,c},{c,d},{d,a}}
 for i,pair in ipairs(xy) do
  v.box2[i].BackgroundColor3=accent()
  draw(v.box2[i],pair[1],pair[2],options.Box2D)
 end
 for i,pair in ipairs(boxEdges) do
  v.box3[i].BackgroundColor3=accent()
  draw(v.box3[i],corners[pair[1]],corners[pair[2]],options.Box3D)
 end
  local joints,bones=skeletonPoints(ch,hum)
  for i,pair in ipairs(bones) do
   local a0=joints[pair[1]];local b0=joints[pair[2]]
   draw(v.skeleton[i],a0 and project(cam,a0),b0 and project(cam,b0),options.Skeleton)
  end
  for i=#bones+1,#v.skeleton do v.skeleton[i].Visible=false end
 local hp=project(cam,head.Position)
 local hw=project(cam,head.Position+cam.CFrame.RightVector*head.Size.X/2)
 local hh=project(cam,head.Position+cam.CFrame.UpVector*head.Size.Y/2)
 v.ring.Visible=options.HeadRing and hp~=nil and hw~=nil and hh~=nil
 if v.ring.Visible then
  local diameter=math.clamp(2.1*math.max((hp-hw).Magnitude,(hp-hh).Magnitude),6,90)
  v.ring.Size=UDim2.fromOffset(diameter,diameter)
  v.ring.Position=UDim2.fromOffset(hp.X,hp.Y)
 end
 v.hp.Visible=options.Health
 if options.Health then
  v.hp.Position=UDim2.fromOffset(x1-11,y1)
  v.hp.Size=UDim2.fromOffset(5,math.max(y2-y1,2))
  local fraction=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
  v.fill.Size=UDim2.fromScale(1,fraction)
  v.fill.BackgroundColor3=C.red:Lerp(C.green,fraction)
 end
 local mid=(x1+x2)/2
 v.name.Visible=options.Names;v.name.Text=p.DisplayName
 v.name.Position=UDim2.fromOffset(mid,y1-40);v.name.Size=UDim2.fromOffset(180,16)
 v.dist.Visible=options.Distance;v.dist.Text=string.format('%.0f studs',distance)
  v.dist.TextColor3=C.white;v.dist.TextSize=15;v.dist.Font=Enum.Font.GothamBold
  v.dist.Position=UDim2.fromOffset(mid,y1-(options.PartyHat and 88 or 25))
 v.dist.Size=UDim2.fromOffset(180,16)
 local weapon=ch:FindFirstChildOfClass('Tool')
 v.weapon.Visible=options.Weapon;v.weapon.Text=weapon and weapon.Name or 'Unarmed'
 v.weapon.Position=UDim2.fromOffset(mid,y2+5)
 v.weapon.Size=UDim2.fromOffset(240,24)
 v.weapon.TextSize=16;v.weapon.Font=Enum.Font.GothamBold
 v.weapon.TextColor3=C.white;v.weapon.TextStrokeTransparency=.12
  -- Projected triangular party hat, with distance label well above its peak.
  local hA=project(cam,head.Position+head.CFrame.UpVector*(head.Size.Y*1.9))
  local hL=project(cam,head.Position+head.CFrame.UpVector*(head.Size.Y*.55)
    -cam.CFrame.RightVector*(head.Size.X*.64))
  local hR=project(cam,head.Position+head.CFrame.UpVector*(head.Size.Y*.55)
    +cam.CFrame.RightVector*(head.Size.X*.64))
  -- Fill from apex to base with reusable horizontal gradient strips.
  -- Interpolating endpoints keeps every strip within the triangle outline.
  for i,strip in ipairs(v.hatFill) do
   local t=(i-.5)/#v.hatFill
   local ok=options.PartyHat and hA and hL and hR
   if ok then
    local left=hA:Lerp(hL,t)
    local right=hA:Lerp(hR,t)
    local span=right-left
    if span.Magnitude>1 then
     strip.Visible=true
     strip.Position=UDim2.fromOffset((left.X+right.X)/2,(left.Y+right.Y)/2)
     strip.Size=UDim2.fromOffset(span.Magnitude,math.max(2,(hL-hA).Magnitude/#v.hatFill+1))
     strip.Rotation=math.deg(math.atan2(span.Y,span.X))
    else strip.Visible=false end
   else strip.Visible=false end
  end
  local hatPairs={{hA,hL},{hA,hR},{hL,hR}}
  local hatColors={Color3.fromRGB(25,80,255),Color3.fromRGB(255,55,183),Color3.fromRGB(48,245,190)}
  for i,segment in ipairs(hatPairs) do
   v.hat[i].BackgroundColor3=hatColors[i]
   draw(v.hat[i],segment[1],segment[2],options.PartyHat)
  end
 local feet=project(cam,root.Position-Vector3.new(0,hum.HipHeight+root.Size.Y/2,0))
 v.tracer.BackgroundColor3=accent()
 draw(v.tracer,Vector2.new(view.X/2,view.Y-10),feet,options.Tracers)
end
-- Launcher: centered loading card (never a full-screen opaque frame).
-- Premium floating shell: soft shadow, layered border and restrained neon edge.
local panelShadow=round(mk('Frame',gui,{Name='LauncherShadow',AnchorPoint=Vector2.new(.5,.5),
 Position=UDim2.new(.5,0,.5,12),Size=UDim2.fromOffset(1018,583),
 BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=.38,
 BorderSizePixel=0,ZIndex=18,Visible=false}),22)
local panel=round(mk('Frame',gui,{Name='Launcher',AnchorPoint=Vector2.new(.5,.5),
 Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(1000,565),
 BackgroundColor3=C.bg,BorderSizePixel=0,ZIndex=20,Visible=false}),19)
stroke(panel,Color3.fromRGB(72,112,151),1.35)
local innerEdge=round(mk('Frame',panel,{Name='InnerEdge',Position=UDim2.fromOffset(4,4),
 Size=UDim2.new(1,-8,1,-8),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=20}),16)
stroke(innerEdge,Color3.fromRGB(37,54,79),1)
local panelScale=mk('UIScale',panel,{Scale=1})
local function fitPanel()
 local camera=workspace.CurrentCamera
 if camera then
  local size=camera.ViewportSize
  local fit=math.min(1,(size.X-24)/1000,(size.Y-24)/565)
  -- Phones get a slightly more usable scale while still fitting the viewport.
  panelScale.Scale=math.max(0.30,fit)
 end
end
fitPanel()
local function syncPanelShadow()
 panelShadow.Visible=panel.Visible
 panelShadow.Position=UDim2.new(.5,0,.5,math.max(7,12*panelScale.Scale))
 panelShadow.Size=UDim2.fromOffset(1018,583)
end
syncPanelShadow()

mk('UIGradient',panel,{Rotation=90,Color=ColorSequence.new({
 ColorSequenceKeypoint.new(0,C.surface),ColorSequenceKeypoint.new(1,C.bg)})})
local header=round(mk('Frame',panel,{Position=UDim2.fromOffset(168,12),
 Size=UDim2.new(1,-180,0,73),BackgroundColor3=C.surface,BorderSizePixel=0,ZIndex=21}),13)
round(mk('Frame',header,{Position=UDim2.fromOffset(14,16),Size=UDim2.fromOffset(56,56),
 BackgroundColor3=C.card,BorderSizePixel=0,ZIndex=22}),12)
label(header,'JX',17,accent(),{Font=Enum.Font.GothamBlack,Position=UDim2.fromOffset(17,19),
 Size=UDim2.fromOffset(36,35),ZIndex=23,TextXAlignment=Enum.TextXAlignment.Center})
label(header,'Jx.studio',18,C.text,{Font=Enum.Font.GothamBold,
 Position=UDim2.fromOffset(64,9),Size=UDim2.fromOffset(230,30),ZIndex=22})
label(header,'PREMIUM CONTROL INTERFACE',9,C.muted,{Position=UDim2.fromOffset(65,40),
 Size=UDim2.fromOffset(250,16),ZIndex=22})
local livePill=round(mk('Frame',header,{Position=UDim2.new(1,-166,0,22),
 Size=UDim2.fromOffset(78,27),BackgroundColor3=Color3.fromRGB(18,52,54),
 BorderSizePixel=0,ZIndex=22}),13)
local liveDot=round(mk('Frame',livePill,{Position=UDim2.fromOffset(10,10),
 Size=UDim2.fromOffset(7,7),BackgroundColor3=C.green,BorderSizePixel=0,ZIndex=23}),4)
label(livePill,'SYSTEM',9,Color3.fromRGB(164,255,218),{Position=UDim2.fromOffset(23,5),
 Size=UDim2.fromOffset(48,16),Font=Enum.Font.GothamBold,ZIndex=23})
mk('UIGradient',header,{Color=ColorSequence.new({
 ColorSequenceKeypoint.new(0,C.surface),ColorSequenceKeypoint.new(1,C.card)}),
 Rotation=0})
local headerAccent=mk('Frame',header,{Position=UDim2.new(0,12,1,-3),
 Size=UDim2.new(1,-24,0,2),BackgroundColor3=accent(),BorderSizePixel=0,ZIndex=23})
mk('UIGradient',headerAccent,{Color=ColorSequence.new({
 ColorSequenceKeypoint.new(0,Color3.fromRGB(47,116,255)),
 ColorSequenceKeypoint.new(.52,Color3.fromRGB(65,224,238)),
 ColorSequenceKeypoint.new(1,Color3.fromRGB(115,104,255))})})
local hideBtn=btn(header,'−',{Position=UDim2.new(1,-75,0,19),Size=UDim2.fromOffset(27,28),ZIndex=23})
local closeBtn=btn(header,'×',{Position=UDim2.new(1,-41,0,19),Size=UDim2.fromOffset(27,28),ZIndex=23})
-- Dedicated left navigation, inspired by the provided reference.
local sidebar=round(mk('Frame',panel,{
 Name='Navigation',Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(155,565),
 BackgroundColor3=Color3.fromRGB(9,12,19),BorderSizePixel=0,ZIndex=24}),18)
mk('UIGradient',sidebar,{Rotation=90,Color=ColorSequence.new({
 ColorSequenceKeypoint.new(0,Color3.fromRGB(16,22,34)),
 ColorSequenceKeypoint.new(1,Color3.fromRGB(8,11,19))})})
mk('Frame',sidebar,{Position=UDim2.fromOffset(154,0),Size=UDim2.fromOffset(1,565),
 BackgroundColor3=C.stroke,BorderSizePixel=0,ZIndex=25})
local logo=round(mk('Frame',sidebar,{Position=UDim2.fromOffset(17,18),
 Size=UDim2.fromOffset(53,53),BackgroundColor3=Color3.fromRGB(14,44,76),
 BorderSizePixel=0,ZIndex=26}),13)
mk('UIGradient',logo,{Rotation=35,Color=ColorSequence.new({
 ColorSequenceKeypoint.new(0,Color3.fromRGB(35,178,255)),
 ColorSequenceKeypoint.new(1,Color3.fromRGB(30,75,215))})})
label(logo,'JX',22,C.white,{Font=Enum.Font.GothamBlack,
 TextXAlignment=Enum.TextXAlignment.Center,
 Position=UDim2.fromOffset(0,7),Size=UDim2.fromOffset(53,38),ZIndex=27})
label(sidebar,'Jx.studio',17,C.white,{Font=Enum.Font.GothamBold,
 Position=UDim2.fromOffset(16,76),Size=UDim2.fromOffset(131,26),ZIndex=26})
label(sidebar,'CONTROL CENTER',9,C.muted,{Font=Enum.Font.GothamMedium,
 Position=UDim2.fromOffset(16,101),Size=UDim2.fromOffset(135,18),ZIndex=26})
mk('Frame',sidebar,{Position=UDim2.fromOffset(13,125),Size=UDim2.fromOffset(129,1),
 BackgroundColor3=C.stroke,BorderSizePixel=0,ZIndex=26})
local tabs=sidebar
local tabNames={{'esp','◈   ESP'},{'aim','◎   AIMBOT'},
 {'weapons','◇   WEAPONS'},{'movement','➤   MOVEMENT'},
 {'appearance','✦   APPEARANCE'},{'misc','▦   MISC'},
 {'settings','⚙   SETTINGS'}}
local tabButtons={}
local tabIndicators={}
for i,item in ipairs(tabNames) do
 local ypos=(item[1]=='settings') and 502 or (142+(i-1)*51)
 local navBtn=btn(tabs,item[2],{Position=UDim2.fromOffset(12,ypos),
  Size=UDim2.fromOffset(131,43),TextSize=11,
  TextXAlignment=Enum.TextXAlignment.Left,ZIndex=27})
 navBtn.BackgroundColor3=Color3.fromRGB(17,24,36)
 tabButtons[item[1]]=navBtn
end
mk('Frame',sidebar,{Position=UDim2.fromOffset(13,487),Size=UDim2.fromOffset(129,1),
 BackgroundColor3=C.stroke,BorderSizePixel=0,ZIndex=26})
local espTab,aimTab,settingsTab=tabButtons.esp,tabButtons.aim,tabButtons.settings
local section=mk('Frame',panel,{BackgroundTransparency=1,Position=UDim2.fromOffset(176,148),
 Size=UDim2.fromOffset(435,296),ZIndex=21})
local settings=mk('Frame',panel,{BackgroundTransparency=1,Position=section.Position,
 Size=section.Size,ZIndex=21,Visible=false})
local aimPane=mk('ScrollingFrame',panel,{Name='AimPanel',BackgroundTransparency=1,Position=section.Position,
 Size=section.Size,CanvasSize=UDim2.fromOffset(0,550),ScrollBarThickness=3,
 ScrollBarImageColor3=accent(),BorderSizePixel=0,ZIndex=21,Visible=false})
local extraPanes={}
for _,id in ipairs({'weapons','movement','appearance','misc'}) do
 extraPanes[id]=mk('ScrollingFrame',panel,{Name=id,BackgroundTransparency=1,
  Position=section.Position,Size=section.Size,CanvasSize=UDim2.fromOffset(0,455),
  ScrollBarThickness=3,ScrollBarImageColor3=accent(),BorderSizePixel=0,
  Visible=false,ZIndex=21})
end
local switches={}
local refreshPreview
local updateWatermark
local order={{'Skeleton','WHITE SKELETON'},{'Box2D','2D BODY BOX'},
 {'Box3D','3D WIREFRAME'},{'HeadRing','WHITE HEAD RING'},
 {'Health','HEALTH BAR'},{'Names','PLAYER NAME'},
 {'Distance','DISTANCE'},{'Weapon','EQUIPPED ITEM'},
 {'Tracers','TRACER LINES'},{'PartyHat','PARTY HAT'}}
-- Live mock-character preview. Pure ScreenGui drawing; no additional viewport camera.
local preview=round(mk('Frame',panel,{Name='Preview',Position=UDim2.fromOffset(638,148),
 Size=UDim2.fromOffset(344,320),BackgroundColor3=C.surface,BorderSizePixel=0,ZIndex=21}),14)
stroke(preview,C.stroke,1)
mk('UIGradient',preview,{Rotation=90,Color=ColorSequence.new({
 ColorSequenceKeypoint.new(0,Color3.fromRGB(27,38,57)),
 ColorSequenceKeypoint.new(1,Color3.fromRGB(12,17,30))})})
label(preview,'LIVE FEATURE PREVIEW',13,C.text,{Font=Enum.Font.GothamBold,
 Position=UDim2.fromOffset(18,12),Size=UDim2.fromOffset(290,22),ZIndex=23})
label(preview,'Updates when you switch features',10,C.muted,{
 Position=UDim2.fromOffset(18,36),Size=UDim2.fromOffset(300,18),ZIndex=23})
local canvas=mk('Frame',preview,{Name='CharacterCanvas',BackgroundTransparency=1,
 Position=UDim2.fromOffset(12,59),Size=UDim2.fromOffset(320,244),ZIndex=23})
-- All coordinates in the canvas's local pixel space.
local function previewStroke(a,b,color,glow)
 local l=line(canvas,color,glow)
 l.ZIndex=27
 local layers=neonLines[l]
 if layers then layers[1].ZIndex=25;layers[2].ZIndex=26 end
 return {line=l,a=Vector2.new(a[1],a[2]),b=Vector2.new(b[1],b[2])}
end
local skeletonSegments={
 {{160,65},{160,105}},{{160,105},{160,135}},
 {{160,86},{132,94}},{{132,94},{118,133}},{{118,133},{106,157}},
 {{160,86},{188,94}},{{188,94},{202,133}},{{202,133},{214,157}},
 {{160,135},{142,160}},{{142,160},{137,198}},{{137,198},{132,226}},
 {{160,135},{178,160}},{{178,160},{183,198}},{{183,198},{188,226}}
}
local skeletonPreview={}
for _,seg in ipairs(skeletonSegments) do
 skeletonPreview[#skeletonPreview+1]=previewStroke(seg[1],seg[2],C.white,true)
end
local boxPreview={}
local boxPoints={{103,42},{217,42},{217,230},{103,230}}
for i=1,4 do boxPreview[#boxPreview+1]=previewStroke(boxPoints[i],boxPoints[i%4+1],accent(),true) end
local box3Preview={}
local front={{103,42},{217,42},{217,230},{103,230}}
local back={{118,27},{232,27},{232,215},{118,215}}
for i=1,4 do
 box3Preview[#box3Preview+1]=previewStroke(front[i],front[i%4+1],accent(),true)
 box3Preview[#box3Preview+1]=previewStroke(back[i],back[i%4+1],accent(),true)
 box3Preview[#box3Preview+1]=previewStroke(front[i],back[i],accent(),true)
end
local tracerPreview=previewStroke({160,244},{160,230},accent(),false)
local dummy=round(mk('Frame',canvas,{BackgroundColor3=Color3.fromRGB(55,68,91),
 Position=UDim2.fromOffset(147,91),Size=UDim2.fromOffset(26,53),BorderSizePixel=0,ZIndex=22}),7)
mk('UIGradient',dummy,{Rotation=90,Color=ColorSequence.new({
 ColorSequenceKeypoint.new(0,Color3.fromRGB(65,82,109)),
 ColorSequenceKeypoint.new(1,Color3.fromRGB(36,48,70))})})
local dummyHead=round(mk('Frame',canvas,{Position=UDim2.fromOffset(143,47),
 Size=UDim2.fromOffset(34,34),BackgroundColor3=Color3.fromRGB(88,104,133),
 BorderSizePixel=0,ZIndex=22}),17)
local headRing=round(mk('Frame',canvas,{Position=UDim2.fromOffset(139,43),
 Size=UDim2.fromOffset(42,42),BackgroundTransparency=1,Visible=false,ZIndex=25}),99)
stroke(headRing,C.white,2)
local healthPreview=round(mk('Frame',canvas,{Position=UDim2.fromOffset(91,44),
 Size=UDim2.fromOffset(5,183),BackgroundColor3=C.green,BorderSizePixel=0,
 Visible=false,ZIndex=25}),3)
local hatLines={}
for _,seg in ipairs({{{160,14},{139,43}},{{160,14},{181,43}},{{139,43},{181,43}}}) do
 hatLines[#hatLines+1]=previewStroke(seg[1],seg[2],Color3.fromRGB(255,155,235),true)
end
local namePreview=label(canvas,'SAMPLE PLAYER',12,C.white,{Position=UDim2.fromOffset(91,5),
 Size=UDim2.fromOffset(138,20),TextXAlignment=Enum.TextXAlignment.Center,
 Font=Enum.Font.GothamBold,ZIndex=26,Visible=false})
local distancePreview=label(canvas,'32 STUDS',13,C.white,{Position=UDim2.fromOffset(110,21),
 Size=UDim2.fromOffset(100,19),TextXAlignment=Enum.TextXAlignment.Center,
 Font=Enum.Font.GothamBold,ZIndex=27,Visible=false})
local weaponPreview=label(canvas,'EQUIPPED: TOOL',12,C.white,{Position=UDim2.fromOffset(87,224),
 Size=UDim2.fromOffset(146,20),TextXAlignment=Enum.TextXAlignment.Center,
 Font=Enum.Font.GothamBold,ZIndex=26,Visible=false})
refreshPreview=function()
 local function refreshSegments(segments,show)
  for _,seg in ipairs(segments) do
   seg.line.BackgroundColor3=seg.line.BackgroundColor3 -- keeps authored line color
   draw(seg.line,seg.a,seg.b,show)
  end
 end
 refreshSegments(skeletonPreview,options.Skeleton)
 refreshSegments(boxPreview,options.Box2D)
 refreshSegments(box3Preview,options.Box3D)
 refreshSegments(hatLines,options.PartyHat)
 draw(tracerPreview.line,tracerPreview.a,tracerPreview.b,options.Tracers)
 headRing.Visible=options.HeadRing
 healthPreview.Visible=options.Health
 namePreview.Visible=options.Names
 distancePreview.Visible=options.Distance
 weaponPreview.Visible=options.Weapon
end
refreshPreview()
local featureDescriptions={
 Skeleton='Shows character joints.', Box2D='Fits a flat outline to the body.',
 Box3D='Displays a 3D body wireframe.', HeadRing='Outlines the head in white.',
 Health='Shows remaining player health.', Names='Shows player display names.',
 Distance='Shows the distance in studs.', Weapon='Shows the equipped Tool.',
 Tracers='Lines toward visible players.', PartyHat='Adds a rainbow party hat.',
 Blur='Blurs the scene behind the menu.', Teammates='Includes players on your team.',
 Watermark='Shows the rainbow Jx.studio label.',
 AimEnabled='Enables aim assistance with hold key or always mode.', AimAlways='Tracks targets without holding the key.', Aim360='Finds targets around you.',
 Triggerbot='Fires at visible TrainingTarget NPCs inside trigger radius.', AimFovShow='Shows the aim radius on screen.',
 NoRecoil='Adjusts exposed recoil properties.', NoSpread='Adjusts exposed spread values.',
 NoSway='Adjusts exposed aim-sway values.', Bhop='Repeats jumps while moving.',
 Speed='Sets local walking speed.', Fly='Moves freely while airborne.',
 Noclip='Disables local body collision.', Skin='Changes local body colors.',
 Model='Shows a fitted character image (asset ID required).', Crosshair='Draws a spinning rainbow crosshair.',
 Chams='Highlights replicated characters.', Spinbot='Rotates your own character.',
}
local function toggleCard(parent,key,title,i,columns)
 local cols=columns or 2;local col=(i-1)%cols;local row=math.floor((i-1)/cols)
 local w=1/cols
 local b=btn(parent,'',{Position=UDim2.new(col*w,col*4,0,row*46),
 Size=UDim2.new(w,-5,0,39),TextXAlignment=Enum.TextXAlignment.Left,
  TextYAlignment=Enum.TextYAlignment.Top,TextSize=11,ZIndex=22})
 label(b,featureDescriptions[key] or '',9,C.muted,{Position=UDim2.fromOffset(12,22),
  Size=UDim2.new(1,-14,0,14),ZIndex=23})
 local function paint()
  b.Text=options[key] and ('  ●  '..title) or ('  ○  '..title)

  b.TextColor3=options[key] and accent() or C.muted
  b.BackgroundColor3=options[key] and C.surface or C.card
 end
 paint();switches[key]=paint
 table.insert(connections,b.MouseButton1Click:Connect(function()
  options[key]=not options[key];paint();blurState();refreshPreview()
   if key=='Watermark' and updateWatermark then updateWatermark() end
 end))
 return b
end
for i,pair in ipairs(order) do toggleCard(section,pair[1],pair[2],i,2) end
toggleCard(settings,'Blur','BACKGROUND BLUR',1,1)
toggleCard(settings,'Teammates','SHOW TEAMMATES',2,1)
toggleCard(settings,'Watermark','RAINBOW WATERMARK',3,1)
local widthBtn=btn(settings,'LINE THICKNESS  :  1 px',{Position=UDim2.fromOffset(0,170),
 Size=UDim2.new(1,-2,0,39),ZIndex=23})
table.insert(connections,widthBtn.MouseButton1Click:Connect(function()
 options.LineWeight=options.LineWeight%4+1
 widthBtn.Text='LINE THICKNESS  :  '..options.LineWeight..' px'
 refreshPreview()
end))
local distanceBtn=btn(settings,'MAX DISTANCE  :  2000 studs',{Position=UDim2.fromOffset(0,220),
 Size=UDim2.new(1,-2,0,39),ZIndex=23})
local limits={250,500,1000,2000,5000};local limitIndex=4
table.insert(connections,distanceBtn.MouseButton1Click:Connect(function()
 limitIndex=limitIndex%#limits+1;options.MaxDistance=limits[limitIndex]
 distanceBtn.Text='MAX DISTANCE  :  '..options.MaxDistance..' studs'
end))
-- English is the default; the language button lives in Settings.
local languageButton=btn(settings,'LANGUAGE  :  ENGLISH',{Position=UDim2.fromOffset(0,266),
 Size=UDim2.new(1,-2,0,29),ZIndex=23,TextSize=11})

-- Translate visible controls rather than duplicating the entire interface.
-- English source strings remain the single source of truth for UI callbacks.
local ko={
 ['CONTROL CENTER']='제어 센터',['LIVE FEATURE PREVIEW']='실시간 기능 미리보기',
 ['Updates when you switch features']='기능을 변경하면 즉시 반영됩니다',
 ['ESP']='ESP',['AIMBOT']='에임봇',['WEAPONS']='무기',['MOVEMENT']='이동',
 ['APPEARANCE']='외형',['MISC']='기타',['SETTINGS']='설정',
 ['WHITE SKELETON']='흰색 스켈레톤',['2D BODY BOX']='2D 박스',
 ['3D WIREFRAME']='3D 박스',['WHITE HEAD RING']='흰색 헤드 링',
 ['HEALTH BAR']='체력 바',['PLAYER NAME']='플레이어 이름',
 ['DISTANCE']='거리',['EQUIPPED ITEM']='장착 무기',
 ['TRACER LINES']='추적선',['PARTY HAT']='파티 모자',
 ['BACKGROUND BLUR']='배경 흐림',['SHOW TEAMMATES']='아군 표시',
 ['RAINBOW WATERMARK']='무지개 워터마크',
 ['LINE THICKNESS']='선 두께',['MAX DISTANCE']='최대 거리',
 ['LANGUAGE']='언어',['ENGLISH']='영어',['KOREAN']='한국어',
 ['CAMERA TARGET ASSIST']='카메라 조준 보조',
 ['AIM ON CLICK']='클릭 조준',['360° LOCK']='360° 조준',
 ['TRIGGERBOT']='트리거봇',['FOV DRAW']='FOV 표시',
 ['TARGET BODY PART']='조준 부위',['TRIGGER FOV']='트리거 반경',
 ['TARGET: HEAD']='조준: 머리',['TARGET: BODY']='조준: 몸통',['TARGET: LEGS']='조준: 다리',
 ['TARGET CONTROLS']='조준 설정',['FOV RADIUS']='FOV 반경',
 ['TRIGGER DELAY']='트리거 지연',['TRIGGER FOV']='트리거 FOV',['AIM SMOOTH']='조준 부드러움',
 ['WEAPON DEBUG']='무기 설정',['MOVEMENT LAB']='이동 설정',
 ['MISC EFFECTS']='기타 효과',
 ['NO RECOIL']='반동 제거',['NO SPREAD']='탄 퍼짐 제거',
 ['NO SWAY']='조준 흔들림 제거',['AUTO BUNNY HOP']='자동 점프',
 ['SPEED CONTROL']='이동 속도',['FLY  (WASD / SPACE / CTRL)']='비행 (WASD / SPACE / CTRL)',
 ['NOCLIP']='벽 통과',['WALK SPEED']='걷기 속도',['FLIGHT SPEED']='비행 속도',
 ['TELEPORT']='순간이동',['CYAN SKIN PRESET']='하늘색 스킨',
 ['MODEL IMAGE OVERLAY']='캐릭터 이미지 오버레이', ['SPINNING RAINBOW CROSSHAIR']='회전 무지개 조준점',
 ['NEON CHARACTER HIGHLIGHT']='네온 캐릭터 강조',['SPIN MY CHARACTER']='캐릭터 회전',
 ['SPIN SPEED']='회전 속도',['Launch']='실행',['Stop']='중지',
 ['READY']='준비',['ACTIVE']='활성화',['ALL MODULES OFF BY DEFAULT']='모든 기능 기본 꺼짐',
 ['FRAME-SYNCED RENDERING']='화면 동기화 렌더링',['OVERLAYS DISABLED']='오버레이 꺼짐',
 ['Shows character joints.']='관절을 선으로 표시합니다.',
 ['Fits a flat outline to the body.']='몸에 맞춰 2D 상자를 표시합니다.',
 ['Displays a 3D body wireframe.']='몸을 감싸는 3D 선을 표시합니다.',
 ['Outlines the head in white.']='머리 주변에 흰 원을 표시합니다.',
 ['Shows remaining player health.']='남은 체력을 표시합니다.',
 ['Shows player display names.']='플레이어 이름을 표시합니다.',
 ['Shows the distance in studs.']='스터드 단위 거리를 표시합니다.',
 ['Shows the equipped Tool.']='장착한 도구를 표시합니다.',
 ['Lines toward visible players.']='화면에서 플레이어까지 선을 표시합니다.',
 ['Adds a rainbow party hat.']='무지개 파티 모자를 표시합니다.',
 ['Blurs the scene behind the menu.']='메뉴 뒤의 배경을 흐리게 합니다.',
 ['Includes players on your team.']='같은 팀도 표시합니다.',
 ['Shows the rainbow Jx.studio label.']='무지개 로고를 표시합니다.',
 ['Hold click to aim at targets.']='클릭하는 동안 조준합니다.',
 ['Finds targets around you.']='주변의 대상을 찾습니다.',
 ['Activates compatible equipped Tools.']='지원되는 도구를 작동합니다.',
 ['Shows the aim radius on screen.']='조준 범위를 화면에 표시합니다.',
 ['Adjusts exposed recoil properties.']='공개된 반동 값을 조정합니다.',
 ['Adjusts exposed spread values.']='공개된 탄 퍼짐 값을 조정합니다.',
 ['Adjusts exposed aim-sway values.']='공개된 흔들림 값을 조정합니다.',
 ['Repeats jumps while moving.']='이동 중 점프를 반복합니다.',
 ['Sets local walking speed.']='로컬 이동 속도를 설정합니다.',
 ['Moves freely while airborne.']='공중에서 자유롭게 이동합니다.',
 ['Disables local body collision.']='로컬 충돌을 끕니다.',
 ['Changes local body colors.']='로컬 캐릭터 색상을 바꿉니다.',
 ['Shows a fitted character image (asset ID required).']='캐릭터에 맞는 이미지를 표시합니다 (에셋 ID 필요).',
 ['Draws a spinning rainbow crosshair.']='회전하는 무지개 조준점을 표시합니다.',
 ['Highlights replicated characters.']='복제된 캐릭터를 강조합니다.',
 ['Rotates your own character.']='내 캐릭터를 회전시킵니다.',
 ['Client-side visualization / self-spin']='클라이언트 시각 효과 / 캐릭터 회전',
 ['Works only with exposed Tool values / attributes']='공개된 도구 값/속성에서만 동작합니다',
 ['Local character movement controls']='로컬 캐릭터 이동 설정',
 ['Client-visible styles for all replicated players']='로컬 캐릭터 외형 및 HUD',
 ['Other players may not see local appearance changes.']='다른 플레이어에게는 외형 변경이 보이지 않을 수 있습니다.',
 ['Changes may be reset by the game server.']='서버에 의해 변경 사항이 초기화될 수 있습니다.',
 ['Custom server-side weapon systems need their own APIs.']='커스텀 무기 시스템에는 별도 API가 필요합니다.',
 ['Applies to all replicated players locally. The built-in Miku-inspired costume needs no upload.']='배경이 투명한 이미지를 Roblox 이미지로 먼저 업로드하세요.',
 ['FOV DRAW defaults ON. 360° aiming ignores the FOV radius.']='FOV 표시 기본 켜짐 · 360° 조준은 FOV 범위를 무시합니다.',
 ['Triggerbot requires click + clear sight. Tool cooldown still applies.']='클릭 중 시야가 확보되면 작동하며 무기 재사용 대기시간이 적용됩니다.',
 ['Trigger FOV is the small orange circle. Aim FOV stays cyan.']='트리거 범위는 주황색 원, 조준 범위는 청록색 원입니다.',
 ['Fires if a target is inside trigger radius.']='트리거 범위 내 대상을 감지하면 발사합니다.',
}
local mappings={}
for en,korean in pairs(ko) do table.insert(mappings,{en,korean}) end
table.sort(mappings,function(a,b) return #a[1]>#b[1] end)
local reverseMappings={}
for _,pair in ipairs(mappings) do table.insert(reverseMappings,pair) end
table.sort(reverseMappings,function(a,b) return #a[2]>#b[2] end)
local function escapePattern(text)
 return text:gsub('([^%w])','%%%1')
end
local function translateString(value,toKorean)
 if type(value)~='string' or value=='' then return value end
 -- Convert the current text back to English before translating. Use placeholders
 -- so shorter translations do not accidentally replace words inside longer ones.
 local work=value
 for i,pair in ipairs(reverseMappings) do
  work=work:gsub(escapePattern(pair[2]), '__JXPH'..i..'END__')
 end
 for i,pair in ipairs(reverseMappings) do
  work=work:gsub(escapePattern('__JXPH'..i..'END__'),pair[1]:gsub('%%','%%%%'))
 end
 if not toKorean then return work end
 for i,pair in ipairs(mappings) do
  work=work:gsub(escapePattern(pair[1]), '__JXPH'..i..'END__')
 end
 for i,pair in ipairs(mappings) do
  work=work:gsub(escapePattern('__JXPH'..i..'END__'),pair[2]:gsub('%%','%%%%'))
 end
 return work
end
local function refreshLanguage()
 local korean=options.Language=='Korean'
 for _,node in ipairs(gui:GetDescendants()) do
  if node:IsA('TextLabel') or node:IsA('TextButton') then
   node.Text=translateString(node.Text,korean)
  end
 end
 languageButton.Text=korean and '언어  :  한국어' or 'LANGUAGE  :  ENGLISH'
end
table.insert(connections,languageButton.MouseButton1Click:Connect(function()
 options.Language=options.Language=='English' and 'Korean' or 'English'
 refreshLanguage()
end))

-- Native developer aim-camera controls (no external process or private executor).
local aimSwitches={}
local function aimToggle(key,title,x,y,w)
 local b=btn(aimPane,'',{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,36),ZIndex=23,
  TextSize=11,TextYAlignment=Enum.TextYAlignment.Top})
 label(b,featureDescriptions[key] or '',9,C.muted,{Position=UDim2.fromOffset(10,20),
  Size=UDim2.new(1,-15,0,13),ZIndex=24})
 local function refresh()
  b.Text=(options[key] and '●  ' or '○  ')..title
  b.BackgroundColor3=options[key] and Color3.fromRGB(23,57,70) or C.card
  b.TextColor3=options[key] and accent() or C.muted
 end
 refresh()
 table.insert(connections,b.MouseButton1Click:Connect(function() options[key]=not options[key];refresh() end))
 aimSwitches[key]=refresh
end
label(aimPane,'CAMERA TARGET ASSIST',12,C.text,{Font=Enum.Font.GothamBold,
 Position=UDim2.fromOffset(2,0),Size=UDim2.fromOffset(400,18),ZIndex=23})
aimToggle('AimEnabled','AIMBOT ENABLE',0,24,209)
aimToggle('Aim360','360° LOCK',216,24,216)
aimToggle('Triggerbot','TRIGGERBOT',0,65,209)
aimToggle('AimFovShow','FOV DRAW',216,65,216)
-- Aim activation mode: hold a configurable key, or use always-on mode.
aimToggle('AimAlways','ALWAYS AIMBOT',0,385,209)
local keyCapture=false
local aimKeyButton=btn(aimPane,'',{Position=UDim2.fromOffset(216,385),
 Size=UDim2.fromOffset(216,36),ZIndex=23,TextSize=11})
local function readableAimKey(key)
 if key==Enum.UserInputType.MouseButton1 then return 'MOUSE 1' end
 if key==Enum.UserInputType.MouseButton2 then return 'MOUSE 2' end
 if typeof(key)=='EnumItem' then return key.Name:upper() end
 return 'MOUSE 1'
end
local function refreshAimKeyButton()
 local korean=options.Language=='Korean'
 if keyCapture then
  aimKeyButton.Text=korean and '키를 누르세요... (ESC 취소)' or 'PRESS A KEY... (ESC cancel)'
 else
  aimKeyButton.Text=(korean and '활성화 키: ' or 'HOLD KEY: ')..readableAimKey(options.AimHoldKey)
 end
end
refreshAimKeyButton()
label(aimPane,'Always Aimbot aims at targets automatically within FOV.',10,C.muted,{
 Position=UDim2.fromOffset(3,433),Size=UDim2.fromOffset(424,18),ZIndex=23})
table.insert(connections,aimKeyButton.MouseButton1Click:Connect(function()
 keyCapture=true;refreshAimKeyButton()
end))
table.insert(connections,UIS.InputBegan:Connect(function(input,gameProcessed)
 if not keyCapture then return end
 -- Don't capture the mouse press used to click the binding button.
 if input.UserInputType==Enum.UserInputType.MouseMovement then return end
 if input.KeyCode==Enum.KeyCode.Escape then keyCapture=false;refreshAimKeyButton();return end
 if input.UserInputType==Enum.UserInputType.Keyboard and input.KeyCode~=Enum.KeyCode.Unknown then
  options.AimHoldKey=input.KeyCode
 elseif input.UserInputType==Enum.UserInputType.MouseButton2 then
  options.AimHoldKey=Enum.UserInputType.MouseButton2
 else
  return
 end
 keyCapture=false;refreshAimKeyButton()
end))

-- Mouse/touch draggable sliders. Values update immediately while dragging.
local function slider(title,key,minValue,maxValue,step,x,y,w,formatter)
 local group=mk('Frame',aimPane,{BackgroundTransparency=1,Position=UDim2.fromOffset(x,y),
  Size=UDim2.fromOffset(w,40),ZIndex=23})
 local caption=label(group,title,10,C.muted,{Position=UDim2.fromOffset(0,0),
  Size=UDim2.fromOffset(w-75,16),ZIndex=24})
 local valueLabel=label(group,'',11,C.text,{Position=UDim2.fromOffset(w-94,0),
  Size=UDim2.fromOffset(94,16),TextXAlignment=Enum.TextXAlignment.Right,ZIndex=24})
 local track=round(mk('Frame',group,{BackgroundColor3=C.stroke,BorderSizePixel=0,
  Position=UDim2.fromOffset(6,27),Size=UDim2.fromOffset(w-12,5),ZIndex=24}),3)
 local fill=round(mk('Frame',track,{BackgroundColor3=accent(),BorderSizePixel=0,
  Size=UDim2.fromScale(0,1),ZIndex=25}),3)
 local knob=round(mk('Frame',track,{BackgroundColor3=C.white,BorderSizePixel=0,
  AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(0,.5),
  Size=UDim2.fromOffset(13,13),ZIndex=26}),99)
 stroke(knob,accent(),1.2)
 local hit=mk('TextButton',group,{BackgroundTransparency=1,Text='',AutoButtonColor=false,
  Position=UDim2.fromOffset(0,17),Size=UDim2.fromOffset(w,23),ZIndex=27})
 local draggingSlider=false
 local activeTouch=nil
 local function paint()
  local fraction=math.clamp((options[key]-minValue)/(maxValue-minValue),0,1)
  fill.Size=UDim2.fromScale(fraction,1)
  knob.Position=UDim2.fromScale(fraction,.5)
  valueLabel.Text=formatter(options[key])
 end
 local function setFromX(posX)
  local ratio=math.clamp((posX-track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1)
  local raw=minValue+ratio*(maxValue-minValue)
  options[key]=math.clamp(minValue+math.floor((raw-minValue)/step+.5)*step,minValue,maxValue)
  paint()
 end
 table.insert(connections,hit.InputBegan:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 then
   draggingSlider=true;setFromX(input.Position.X)
  elseif input.UserInputType==Enum.UserInputType.Touch then
   draggingSlider=true;activeTouch=input;setFromX(input.Position.X)
  end
 end))
 table.insert(connections,UIS.InputChanged:Connect(function(input)
  if draggingSlider and (input.UserInputType==Enum.UserInputType.MouseMovement or input==activeTouch) then
   setFromX(input.Position.X)
  end
 end))
 table.insert(connections,UIS.InputEnded:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input==activeTouch then
   draggingSlider=false;activeTouch=nil
  end
 end))
 paint()
 return paint
end
-- Additional client-side development controls. Server-authoritative games may override changes.
local featureButtons={}
local function featureToggle(pane,key,title,y,callback)
 local button=btn(pane,'',{Position=UDim2.fromOffset(3,y),Size=UDim2.fromOffset(411,38),ZIndex=23,
  TextYAlignment=Enum.TextYAlignment.Top,TextSize=11})
 label(button,featureDescriptions[key] or '',10,C.muted,{Position=UDim2.fromOffset(15,21),
  Size=UDim2.new(1,-25,0,15),ZIndex=24})
 local function refresh()
  button.Text=(options[key] and '  ●  ' or '  ○  ')..title
  button.TextColor3=options[key] and accent() or C.muted
  button.BackgroundColor3=options[key] and C.surface or C.card
 end
 refresh()
 table.insert(connections,button.MouseButton1Click:Connect(function()
  options[key]=not options[key];refresh()
  if callback then callback(options[key]) end
 end))
 featureButtons[key]=refresh
end
local function paneTitle(pane,title,desc)
 label(pane,title,13,C.text,{Font=Enum.Font.GothamBold,Position=UDim2.fromOffset(4,5),Size=UDim2.fromOffset(408,25),ZIndex=23})
 label(pane,desc,10,C.muted,{Position=UDim2.fromOffset(4,30),Size=UDim2.fromOffset(408,18),ZIndex=23})
end
-- Weapon modifiers are only effective if your own weapon code reads the corresponding values.
local toolOriginals=setmetatable({},{__mode='k'})
local weaponFields={NoRecoil={'Recoil','RecoilAmount','CameraRecoil'},
 NoSpread={'Spread','BulletSpread','AccuracySpread'},NoSway={'Sway','AimSway','SwayAmount'}}
local function weaponUpdate()
 local ch=player.Character
 local tool=ch and ch:FindFirstChildOfClass('Tool')
 if not tool then return end
 for key,names in pairs(weaponFields) do
  for _,name in ipairs(names) do
   local node=tool:FindFirstChild(name,true)
   if node and (node:IsA('NumberValue') or node:IsA('IntValue')) then
    local original=toolOriginals[node]
    if original==nil then original=node.Value;toolOriginals[node]=original end
    node.Value=options[key] and 0 or original
   end
   local attribute=tool:GetAttribute(name)
   if type(attribute)=='number' then
    local bag=toolOriginals[tool] or {};toolOriginals[tool]=bag
    if bag[name]==nil then bag[name]=attribute end
    tool:SetAttribute(name,options[key] and 0 or bag[name])
   end
  end
 end
end
paneTitle(extraPanes.weapons,'WEAPON DEBUG','Works only with exposed Tool values / attributes')
featureToggle(extraPanes.weapons,'NoRecoil','NO RECOIL',59,weaponUpdate)
featureToggle(extraPanes.weapons,'NoSpread','NO SPREAD',101,weaponUpdate)
featureToggle(extraPanes.weapons,'NoSway','NO SWAY',143,weaponUpdate)
label(extraPanes.weapons,'Custom server-side weapon systems need their own APIs.',10,C.muted,
 {Position=UDim2.fromOffset(4,194),Size=UDim2.fromOffset(406,32),TextWrapped=true,ZIndex=23})
local savedSpeed,savedAutoRotate=nil,nil
local savedCollision=setmetatable({},{__mode='k'})
local flightAttachment,flightVelocity=nil,nil
local function removeFlight()
 if flightVelocity then flightVelocity:Destroy();flightVelocity=nil end
 if flightAttachment then flightAttachment:Destroy();flightAttachment=nil end
end
local function flightUpdate(dt)
 if not options.Fly then removeFlight();return end
 local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
 local hum=player.Character and player.Character:FindFirstChildOfClass('Humanoid')
 if not root or not hum then removeFlight();return end
 if not flightAttachment or flightAttachment.Parent~=root then
  removeFlight()
  flightAttachment=Instance.new('Attachment');flightAttachment.Name='JxFlyAttachment';flightAttachment.Parent=root
  flightVelocity=Instance.new('LinearVelocity');flightVelocity.Name='JxFlyVelocity'
  flightVelocity.Attachment0=flightAttachment;flightVelocity.MaxForce=100000000
  flightVelocity.VectorVelocity=Vector3.zero;flightVelocity.RelativeTo=Enum.ActuatorRelativeTo.World
  flightVelocity.Parent=root
 end
 local cam=workspace.CurrentCamera
 if not cam then return end
 local dir=Vector3.zero
 if UIS:IsKeyDown(Enum.KeyCode.W) then dir+=cam.CFrame.LookVector end
 if UIS:IsKeyDown(Enum.KeyCode.S) then dir-=cam.CFrame.LookVector end
 if UIS:IsKeyDown(Enum.KeyCode.D) then dir+=cam.CFrame.RightVector end
 if UIS:IsKeyDown(Enum.KeyCode.A) then dir-=cam.CFrame.RightVector end
 if UIS:IsKeyDown(Enum.KeyCode.Space) then dir+=Vector3.yAxis end
 if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir-=Vector3.yAxis end
 flightVelocity.VectorVelocity=dir.Magnitude>0 and dir.Unit*options.FlySpeed or Vector3.zero
 hum:ChangeState(Enum.HumanoidStateType.Freefall)
end
local function restoreMovement()
 options.Fly=false;removeFlight()
 local hum=player.Character and player.Character:FindFirstChildOfClass('Humanoid')
 if hum and savedSpeed then hum.WalkSpeed=savedSpeed end
 if hum and savedAutoRotate~=nil then hum.AutoRotate=savedAutoRotate end
 for part,value in pairs(savedCollision) do if part.Parent then part.CanCollide=value end end
 savedCollision=setmetatable({},{__mode='k'})
end
paneTitle(extraPanes.movement,'MOVEMENT LAB','Local character movement controls')
featureToggle(extraPanes.movement,'Bhop','AUTO BUNNY HOP',57)
featureToggle(extraPanes.movement,'Speed','SPEED CONTROL',98)
featureToggle(extraPanes.movement,'Fly','FLY  (WASD / SPACE / CTRL)',139)
featureToggle(extraPanes.movement,'Noclip','NOCLIP',180)
-- Slider controls intentionally use a shared mouse/touch handling pattern.
local function paneSlider(pane,title,key,minV,maxV,step,y,unit)
 local titleLabel=label(pane,title,11,C.muted,{Position=UDim2.fromOffset(5,y),Size=UDim2.fromOffset(295,19),ZIndex=24})
 local value=label(pane,'',11,C.text,{Position=UDim2.fromOffset(302,y),Size=UDim2.fromOffset(110,19),ZIndex=24,TextXAlignment=Enum.TextXAlignment.Right})
 local track=round(mk('Frame',pane,{Position=UDim2.fromOffset(5,y+26),Size=UDim2.fromOffset(405,6),BackgroundColor3=C.stroke,BorderSizePixel=0,ZIndex=23}),3)
 local fill=round(mk('Frame',track,{Size=UDim2.fromScale(0,1),BackgroundColor3=accent(),BorderSizePixel=0,ZIndex=24}),3)
 local hit=mk('TextButton',pane,{Text='',BackgroundTransparency=1,Position=UDim2.fromOffset(0,y+17),Size=UDim2.fromOffset(415,30),ZIndex=25})
 local dragging=false;local touch=nil
 local function repaint()
  local f=math.clamp((options[key]-minV)/(maxV-minV),0,1)
  fill.Size=UDim2.fromScale(f,1);value.Text=tostring(math.floor(options[key]+.5))..(unit or '')
 end
 local function setX(x)
  local f=math.clamp((x-track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1)
  options[key]=math.clamp(minV+math.floor((f*(maxV-minV))/step+.5)*step,minV,maxV)
  repaint()
 end
 table.insert(connections,hit.InputBegan:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true;setX(input.Position.X)
  elseif input.UserInputType==Enum.UserInputType.Touch then dragging=true;touch=input;setX(input.Position.X) end
 end))
 table.insert(connections,UIS.InputChanged:Connect(function(input)
  if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input==touch) then setX(input.Position.X) end
 end))
 table.insert(connections,UIS.InputEnded:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseButton1 or input==touch then dragging=false;touch=nil end
 end))
 repaint()
end
paneSlider(extraPanes.movement,'WALK SPEED','SpeedValue',8,60,1,230,' studs/s')
paneSlider(extraPanes.movement,'FLIGHT SPEED','FlySpeed',5,1200,5,290,' studs/s')
local coords=mk('TextBox',extraPanes.movement,{Position=UDim2.fromOffset(4,354),Size=UDim2.fromOffset(285,35),
 Text='0, 10, 0',PlaceholderText='X, Y, Z',TextColor3=C.text,BackgroundColor3=C.card,
 Font=Enum.Font.Code,TextSize=13,ClearTextOnFocus=false,ZIndex=24})
round(coords,7)
local teleportBtn=btn(extraPanes.movement,'TELEPORT',{Position=UDim2.fromOffset(296,354),Size=UDim2.fromOffset(116,35),ZIndex=24})
table.insert(connections,teleportBtn.MouseButton1Click:Connect(function()
 local a,b,c=coords.Text:match('^%s*([%-%.%d]+)%s*,%s*([%-%.%d]+)%s*,%s*([%-%.%d]+)%s*$')
 local x,y,z=tonumber(a),tonumber(b),tonumber(c)
 local ch=player.Character
 if x and y and z and ch and ch.PrimaryPart then ch:PivotTo(CFrame.new(x,y,z))
 else coords.Text='Enter X, Y, Z' end
end))
label(extraPanes.movement,'Changes may be reset by the game server.',10,C.muted,
 {Position=UDim2.fromOffset(5,397),Size=UDim2.fromOffset(395,18),ZIndex=23})
-- Local appearance effects: original appearance restored when disabled.
-- A PNG cannot be transformed into a 3D Roblox rig automatically.
-- Model uses a Roblox image asset; no fallback costume is created on failed loading.
-- An exact copy of a user PNG still requires an accessible image asset.
-- Local-only appearance manager for every replicated character.
-- Image avatar uses the built-in image ID by default, or optional user override. BillboardGui faces the camera.
-- Image asset must be approved and usable in the experience; transparent artwork is recommended.
local DEFAULT_MIKU_IMAGE_ID='96902595564359' -- Texture ID for decal asset 73910565810611; optional input stays empty.
local characterArtId=DEFAULT_MIKU_IMAGE_ID -- Image for 2D character overlay.
local mikuTeal=Color3.fromRGB(46,215,208)
local cyanSkin=Color3.fromRGB(95,205,255)
local appearanceEntries={}
local bodyNames={Head=true,Torso=true,UpperTorso=true,LowerTorso=true,
 LeftUpperArm=true,LeftLowerArm=true,LeftHand=true,RightUpperArm=true,RightLowerArm=true,RightHand=true,
 LeftUpperLeg=true,LeftLowerLeg=true,LeftFoot=true,RightUpperLeg=true,RightLowerLeg=true,RightFoot=true,
 ['Left Arm']=true,['Right Arm']=true,['Left Leg']=true,['Right Leg']=true}
local function addCostumePart(folder,anchor,name,offset,size,color,material)
 local part=Instance.new('Part')
 part.Name=name;part.Size=size;part.Color=color
 part.Material=material or Enum.Material.SmoothPlastic
 part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
 part.Anchored=false;part.Massless=true;part.CastShadow=false
 part.CFrame=anchor.CFrame*offset;part.Parent=folder
 local weld=Instance.new('WeldConstraint')
 weld.Part0=anchor;weld.Part1=part;weld.Parent=part
 return part
end
local function restoreAppearance(p)
 local entry=appearanceEntries[p]
 if not entry then return end
 if entry.folder then entry.folder:Destroy() end
 if entry.image then entry.image:Destroy() end
 for part,original in pairs(entry.original) do
  if part and part.Parent then
   part.Color=original.color
   part.Material=original.material
   part.LocalTransparencyModifier=original.transparency
  end
 end
 appearanceEntries[p]=nil
end
local function createMikuCover(ch,folder)
 local head=ch:FindFirstChild('Head')
 local torso=ch:FindFirstChild('UpperTorso') or ch:FindFirstChild('Torso')
 local black=Color3.fromRGB(29,30,42)
 local white=Color3.fromRGB(232,239,244)
 local skin=Color3.fromRGB(249,217,201)
 -- Build shells around body pieces: front, sides and back, not flat panels.
 for _,part in ipairs(ch:GetChildren()) do
  if part:IsA('BasePart') and bodyNames[part.Name] then
   local n=part.Name
   local material=Enum.Material.SmoothPlastic
   local shade=skin
   if n=='Head' then shade=skin
   elseif n=='Torso' or n=='UpperTorso' then shade=white
   elseif n=='LowerTorso' then shade=black
   elseif n:find('Leg') or n:find('Foot') then shade=black
   elseif n:find('Hand') then shade=skin
   elseif n:find('Arm') then shade=(n:find('Lower') or n=='Left Arm' or n=='Right Arm') and black or skin end
   addCostumePart(folder,part,'MikuShell_'..n,CFrame.new(),part.Size+Vector3.new(.055,.055,.055),shade,material)
  end
 end
 if head then
  addCostumePart(folder,head,'TealHairCap',CFrame.new(0,.38,0),Vector3.new(1.18,.34,1.04),mikuTeal)
  for _,side in ipairs({-1,1}) do
   addCostumePart(folder,head,'HairTie',CFrame.new(side*.63,.38,0),Vector3.new(.23,.22,.25),black)
   for i=1,4 do
    local offset=CFrame.new(side*(.68+i*.13),.15-i*.42,.06)*CFrame.Angles(0,0,side*math.rad(9))
    addCostumePart(folder,head,'TwinTail_'..side..'_'..i,offset,Vector3.new(.30,.54,.31),mikuTeal)
   end
  end
 end
 if torso then
  addCostumePart(folder,torso,'TealTie',CFrame.new(0,.02,-torso.Size.Z*.55),Vector3.new(.18,.82,.08),mikuTeal)
  addCostumePart(folder,torso,'Collar',CFrame.new(0,torso.Size.Y*.38,-torso.Size.Z*.55),Vector3.new(.83,.11,.09),mikuTeal)
 end
end
local function updatePlayerAppearance(p)
 local ch=p.Character
 local entry=appearanceEntries[p]
 if entry and (entry.character~=ch or not p.Parent) then
  restoreAppearance(p);entry=nil
 end
 if not ch or not (options.Skin or options.Model) then
  if entry then restoreAppearance(p) end
  return
 end
 if not entry then
  entry={character=ch,original={},mode=nil,folder=nil,image=nil,imageStatus='pending'}
  appearanceEntries[p]=entry
 end
 if not options.Model then
  for part,original in pairs(entry.original) do
   if part.Parent and not bodyNames[part.Name] then
    part.LocalTransparencyModifier=original.transparency
   end
  end
 end
 local mode=options.Model and 'model' or 'skin'
 local desired=mode..':'..(options.Model and characterArtId or '')
 if entry.mode~=desired then
  if entry.folder then entry.folder:Destroy();entry.folder=nil end
  if entry.image then entry.image:Destroy();entry.image=nil end
  entry.mode=desired
  entry.imageStatus='pending'
  if options.Model and characterArtId=='' then
   entry.folder=Instance.new('Folder');entry.folder.Name='JxMikuInspiredLocal'
   entry.folder.Parent=ch
   createMikuCover(ch,entry.folder)
  elseif options.Model then
   local root=ch:FindFirstChild('HumanoidRootPart')
   if root then
    local billboard=Instance.new('BillboardGui')
    billboard.Name='JxMikuImageLocal';billboard.Adornee=root
    billboard.AlwaysOnTop=true;billboard.LightInfluence=0
    billboard.MaxDistance=0
    -- Size image to the character's visible body (without accessories or tools).
    local minimum=Vector3.new(math.huge,math.huge,math.huge)
    local maximum=Vector3.new(-math.huge,-math.huge,-math.huge)
    for _,part in ipairs(ch:GetChildren()) do
     if part:IsA('BasePart') and bodyNames[part.Name] then
      local half=part.Size*0.5
      for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
       local world=part.CFrame:PointToWorldSpace(Vector3.new(x*half.X,y*half.Y,z*half.Z))
       local point=root.CFrame:PointToObjectSpace(world)
       minimum=Vector3.new(math.min(minimum.X,point.X),math.min(minimum.Y,point.Y),math.min(minimum.Z,point.Z))
       maximum=Vector3.new(math.max(maximum.X,point.X),math.max(maximum.Y,point.Y),math.max(maximum.Z,point.Z))
      end end end
     end
    end
    local height=(maximum.Y>minimum.Y) and (maximum.Y-minimum.Y) or 5
    local width=(maximum.X>minimum.X) and (maximum.X-minimum.X) or 3
    billboard.Size=UDim2.new(math.max(width*1.3,2.6),0,height*1.12,0)
    billboard.StudsOffsetWorldSpace=Vector3.new(0,(maximum.Y>minimum.Y) and ((maximum.Y+minimum.Y)/2) or .7,0)
    billboard.Parent=pg
    local art=Instance.new('ImageLabel');art.BackgroundTransparency=1
    art.Size=UDim2.fromScale(1,1);art.ScaleType=Enum.ScaleType.Fit
    art.Image='rbxassetid://'..characterArtId;art.Parent=billboard
    entry.image=billboard
    -- Never hide the avatar until the actual image has loaded.
    -- An inaccessible or non-image asset can otherwise make everyone invisible.
    entry.imageStatus='loading'
    local pendingEntry=entry
    task.spawn(function()
     local deadline=os.clock()+15
     while alive and pendingEntry.imageStatus=='loading' and os.clock()<deadline do
      if art.IsLoaded then break end
      task.wait(.15)
     end
     if not alive or appearanceEntries[p]~=pendingEntry or pendingEntry.image~=billboard then return end
     if art.IsLoaded then
      pendingEntry.imageStatus='ready'
      -- Image is now available: the avatar is hidden by updatePlayerAppearance.
     else
      pendingEntry.imageStatus='failed'
      billboard:Destroy();pendingEntry.image=nil
      -- Keep the normal avatar visible if the image isn't accessible.
      -- Do not replace it with the older block-built Miku costume.
      warn('[Jx.studio] Image '..characterArtId..' failed to load. Check asset permissions in Studio Output.')
     end
     if p.Parent==Players then updatePlayerAppearance(p) end
    end)
   end
  end
 end
 -- Hide original accessory handles as well, otherwise hats/hair show through the costume.
 if options.Model and (entry.imageStatus=='ready') then
  for _,accessory in ipairs(ch:GetChildren()) do
   if accessory:IsA('Accessory') then
    for _,handle in ipairs(accessory:GetDescendants()) do
     if handle:IsA('BasePart') then
      if not entry.original[handle] then
       entry.original[handle]={color=handle.Color,material=handle.Material,
        transparency=handle.LocalTransparencyModifier}
      end
      handle.LocalTransparencyModifier=1
     end
    end
   end
  end
 end
 for _,part in ipairs(ch:GetChildren()) do
  if part:IsA('BasePart') and bodyNames[part.Name] then
   if not entry.original[part] then
    entry.original[part]={color=part.Color,material=part.Material,
      transparency=part.LocalTransparencyModifier}
   end
   local original=entry.original[part]
   if options.Model and (entry.imageStatus=='ready') then
    part.LocalTransparencyModifier=1
   else
    part.LocalTransparencyModifier=original.transparency
    if options.Skin then
     part.Color=cyanSkin
     part.Material=Enum.Material.SmoothPlastic
    else
     part.Color=original.color
     part.Material=original.material
    end
   end
  end
 end
end
local function appearanceUpdate()
 for _,p in ipairs(Players:GetPlayers()) do updatePlayerAppearance(p) end
 for p in pairs(appearanceEntries) do
  if p.Parent~=Players then restoreAppearance(p) end
 end
end
local crosshair=mk('Frame',overlay,{BackgroundTransparency=1,Size=UDim2.fromOffset(56,56),
 AnchorPoint=Vector2.new(.5,.5),Visible=false,ZIndex=11})
local crossLines={}
for i=1,4 do
 local bar=round(mk('Frame',crosshair,{BackgroundColor3=accent(),BorderSizePixel=0,
  AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromOffset(28,28),Size=UDim2.fromOffset(17,3),ZIndex=12}),1)
 bar.Rotation=(i-1)*90
 bar.Position=UDim2.fromOffset(28+math.cos(math.rad((i-1)*90))*16,
 28+math.sin(math.rad((i-1)*90))*16)
 mk('UIStroke',bar,{Thickness=1.1,Color=Color3.fromRGB(20,24,31),Transparency=.2})
 crossLines[i]=bar
end
paneTitle(extraPanes.appearance,'APPEARANCE','Client-visible styles for all replicated players')
featureToggle(extraPanes.appearance,'Skin','CYAN SKIN PRESET',57,appearanceUpdate)
featureToggle(extraPanes.appearance,'Model','MIKU-INSPIRED MODEL',99,appearanceUpdate)
featureToggle(extraPanes.appearance,'Crosshair','SPINNING RAINBOW CROSSHAIR',141)
label(extraPanes.appearance,'Default Miku image applies when the ID field is blank. Image access must be allowed.',10,C.muted,
 {Position=UDim2.fromOffset(4,195),Size=UDim2.fromOffset(405,32),TextWrapped=true,ZIndex=23})
local assetInput=mk('TextBox',extraPanes.appearance,{
 Position=UDim2.fromOffset(5,241),Size=UDim2.fromOffset(392,36),
 BackgroundColor3=C.card,TextColor3=C.text,PlaceholderColor3=C.muted,
 Text='',PlaceholderText='Optional Image ID (blank = default Miku)',TextSize=12,
 Font=Enum.Font.Gotham,ClearTextOnFocus=false,ZIndex=24})
round(assetInput,8)
table.insert(connections,assetInput.FocusLost:Connect(function()
 local n=assetInput.Text:match('(%d+)')
 characterArtId=n or DEFAULT_MIKU_IMAGE_ID
 appearanceUpdate()
end))
table.insert(connections,Players.PlayerRemoving:Connect(function(p) restoreAppearance(p) end))
table.insert(connections,Players.PlayerAdded:Connect(function(p)
 table.insert(connections,p.CharacterAdded:Connect(function()
  task.delay(.5,function() if alive then updatePlayerAppearance(p) end end)
 end))
end))
local chamObjects={}
local function updateChams()
 for target,obj in pairs(chamObjects) do
  if not options.Chams or target.Parent~=Players or obj.Adornee~=target.Character then
   obj:Destroy();chamObjects[target]=nil
  end
 end
 if not options.Chams then return end
 for _,target in ipairs(Players:GetPlayers()) do
  if target~=player and target.Character and not chamObjects[target] then
   local highlight=Instance.new('Highlight')
   highlight.Name='JxClientCham';highlight.Adornee=target.Character
   highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
   highlight.FillColor=Color3.fromRGB(75,200,255)
   highlight.FillTransparency=.55;highlight.OutlineColor=accent()
   highlight.OutlineTransparency=.08
   highlight.Parent=gui
   chamObjects[target]=highlight
  end
 end
end
paneTitle(extraPanes.misc,'MISC EFFECTS','Client-side visualization / self-spin')
featureToggle(extraPanes.misc,'Chams','NEON CHARACTER HIGHLIGHT',57,updateChams)
featureToggle(extraPanes.misc,'Spinbot','SPIN MY CHARACTER',99)
paneSlider(extraPanes.misc,'SPIN SPEED','SpinSpeed',30,7200,30,159,' °/s')
label(extraPanes.misc,'Other players may not see local appearance changes.',10,C.muted,
 {Position=UDim2.fromOffset(5,225),Size=UDim2.fromOffset(401,32),TextWrapped=true,ZIndex=23})
local lastFeatureUpdate=0
local function featureUpdate(dt,cam)
 local now=os.clock()
 local hum=player.Character and player.Character:FindFirstChildOfClass('Humanoid')
 local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
 if hum then
  if savedSpeed==nil then savedSpeed=hum.WalkSpeed end
  hum.WalkSpeed=options.Speed and options.SpeedValue or savedSpeed
  if options.Bhop and hum.FloorMaterial~=Enum.Material.Air and not UIS:GetFocusedTextBox() then
   hum.Jump=true
  end
  if savedAutoRotate==nil then savedAutoRotate=hum.AutoRotate end
  if options.Spinbot and root then
   hum.AutoRotate=false
   root.CFrame=root.CFrame*CFrame.Angles(0,math.rad(options.SpinSpeed)*math.clamp(dt,0,.1),0)
  else hum.AutoRotate=savedAutoRotate end
 end
 if player.Character then
  for _,part in ipairs(player.Character:GetDescendants()) do
   if part:IsA('BasePart') then
    if options.Noclip then
     if savedCollision[part]==nil then savedCollision[part]=part.CanCollide end
     part.CanCollide=false
    elseif savedCollision[part]~=nil then
     part.CanCollide=savedCollision[part];savedCollision[part]=nil
    end
   end
  end
 end
 flightUpdate(dt)
 if now-lastFeatureUpdate>.25 then
  lastFeatureUpdate=now
  weaponUpdate();appearanceUpdate();updateChams()
 end
 crosshair.Visible=options.Crosshair and enabled and not loading
 if crosshair.Visible and cam then
  crosshair.Position=UDim2.fromOffset(cam.ViewportSize.X*.5,cam.ViewportSize.Y*.5)
  crosshair.Rotation=(now*24)%360
  local color=Color3.fromHSV((now*.12)%1,.74,1)
  for _,bar in ipairs(crossLines) do bar.BackgroundColor3=color end
 end
end
local function cleanupFeatures()
 restoreMovement()
 for obj,original in pairs(toolOriginals) do
  if obj and obj.Parent then
   if obj:IsA('NumberValue') or obj:IsA('IntValue') then
    if type(original)=='number' then obj.Value=original end
   elseif obj:IsA('Tool') and type(original)=='table' then
    for name,value in pairs(original) do obj:SetAttribute(name,value) end
   end
  end
 end
 for p in pairs(appearanceEntries) do restoreAppearance(p) end
 for _,hl in pairs(chamObjects) do hl:Destroy() end
 removeFlight()
end
-- End of local developer feature modules.

label(aimPane,'TARGET CONTROLS',11,C.muted,{Position=UDim2.fromOffset(3,112),Size=UDim2.fromOffset(330,18),ZIndex=23})
slider('FOV RADIUS','AimFov',40,450,5,0,137,209,function(x)return math.floor(x+.5)..' px' end)
slider('TRIGGER DELAY','TriggerDelay',0.005,0.2,0.005,216,137,216,
 function(x)return math.floor(x*1000+.5)..' ms' end)
slider('AIM SMOOTH','AimSmooth',5,40,1,0,183,209,function(x)return math.floor(x+.5)..'  (lower = faster)' end)
label(aimPane,'FOV DRAW defaults ON. 360° aiming ignores the FOV radius.',10,C.muted,{
 Position=UDim2.fromOffset(3,228),Size=UDim2.fromOffset(430,19),ZIndex=23})
label(aimPane,'Targets: NPC models tagged TrainingTarget. Clear line of sight required.',10,C.muted,{
 Position=UDim2.fromOffset(3,247),Size=UDim2.fromOffset(430,19),ZIndex=23})
label(aimPane,'TARGET BODY PART',10,C.muted,{Position=UDim2.fromOffset(3,277),
 Size=UDim2.fromOffset(209,18),ZIndex=23})
local aimParts={'Head','Body','Legs'}
local aimPartButton=btn(aimPane,'HEAD  ▼',{Position=UDim2.fromOffset(0,298),
 Size=UDim2.fromOffset(209,37),ZIndex=23,TextSize=12})
local aimPartIndex=1
local function paintAimPart()
 local korean=options.Language=='Korean'
 local terms=korean and {Head='머리',Body='몸통',Legs='다리'}
  or {Head='HEAD',Body='BODY',Legs='LEGS'}
 aimPartButton.Text=(korean and '조준: ' or 'TARGET: ')..terms[options.AimPart]..'  ▼'
end
paintAimPart()
table.insert(connections,aimPartButton.MouseButton1Click:Connect(function()
 aimPartIndex=aimPartIndex%#aimParts+1
 options.AimPart=aimParts[aimPartIndex]
 paintAimPart()
end))
slider('TRIGGER FOV','TriggerFov',8,140,2,216,294,216,
 function(x) return math.floor(x+.5)..' px' end)
label(aimPane,MOBILE and 'Touch: hold FIRE to aim and trigger. Tag NPCs TrainingTarget.' or 'Trigger FOV is orange; aim FOV is cyan. NPCs need TrainingTarget tag.',10,C.muted,{
 Position=UDim2.fromOffset(3,354),Size=UDim2.fromOffset(425,16),ZIndex=23})
local fovCircle=round(mk('Frame',overlay,{Name='AimFOV',BackgroundTransparency=1,
 AnchorPoint=Vector2.new(.5,.5),Visible=false,ZIndex=8}),999)
local fovStroke=stroke(fovCircle,accent(),1.4)
fovStroke.Transparency=.3
local triggerCircle=round(mk('Frame',overlay,{Name='TriggerFOV',BackgroundTransparency=1,
 AnchorPoint=Vector2.new(.5,.5),Visible=false,ZIndex=8}),999)
local triggerStroke=stroke(triggerCircle,Color3.fromRGB(255,187,95),1.8)
triggerStroke.Transparency=.12

-- Touch trigger control. It is only shown on touch-first devices.
local mobileTriggerButton=round(btn(gui,'FIRE',{AnchorPoint=Vector2.new(1,1),
 Position=UDim2.new(1,-22,1,-34),Size=UDim2.fromOffset(116,58),
 BackgroundColor3=Color3.fromRGB(38,75,96),TextColor3=C.white,
 TextSize=16,ZIndex=90,Visible=MOBILE}),14)
stroke(mobileTriggerButton,accent(),1.5)
local function setMobileTrigger(held)
 mobileTriggerHeld=held
 mobileTriggerButton.BackgroundColor3=held and Color3.fromRGB(30,130,145)
  or Color3.fromRGB(38,75,96)
end
table.insert(connections,mobileTriggerButton.InputBegan:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
  setMobileTrigger(true)
 end
end))
table.insert(connections,mobileTriggerButton.InputEnded:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
  setMobileTrigger(false)
 end
end))
local lastShot=0
local function getTargetPart(character)
 if options.AimPart=='Head' then
  return character:FindFirstChild('Head')
 elseif options.AimPart=='Body' then
  return character:FindFirstChild('UpperTorso') or character:FindFirstChild('Torso')
   or character:FindFirstChild('LowerTorso') or character:FindFirstChild('HumanoidRootPart')
 else
  return character:FindFirstChild('LeftLowerLeg') or character:FindFirstChild('RightLowerLeg')
   or character:FindFirstChild('Left Leg') or character:FindFirstChild('Right Leg')
   or character:FindFirstChild('LeftFoot')
 end
end
local function aimUpdate(dt,cam)
 local active=options.AimEnabled and enabled and not loading
 fovCircle.Visible=active and options.AimFovShow
 triggerCircle.Visible=active and options.Triggerbot
 local middle=cam.ViewportSize*.5
 if fovCircle.Visible then
  fovCircle.Size=UDim2.fromOffset(options.AimFov*2,options.AimFov*2)
  fovCircle.Position=UDim2.fromOffset(middle.X,middle.Y)
 end
 if triggerCircle.Visible then
  triggerCircle.Size=UDim2.fromOffset(options.TriggerFov*2,options.TriggerFov*2)
  triggerCircle.Position=UDim2.fromOffset(middle.X,middle.Y)
 end
 if not active then return end
 local held
 if options.AimHoldKey==Enum.UserInputType.MouseButton1 or options.AimHoldKey==Enum.UserInputType.MouseButton2 then
  held=UIS:IsMouseButtonPressed(options.AimHoldKey)
 else
  held=UIS:IsKeyDown(options.AimHoldKey)
 end
 local aimEngaged=options.AimAlways or held or (MOBILE and mobileTriggerHeld)
 if not aimEngaged then return end
 local bestPoint,bestScore=nil,math.huge
 local triggerPart,triggerScore=nil,math.huge
 local ownRoot=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
 local origin=cam.CFrame.Position
 local rayParams=RaycastParams.new()
 rayParams.FilterType=Enum.RaycastFilterType.Exclude
 rayParams.FilterDescendantsInstances={player.Character}
 -- Binary visibility test: a target is valid only when the first ray hit
 -- belongs to that target model. Tag NPC models with "TrainingTarget".
 local function isVisible(part,model)
  local offset=part.Position-origin
  if offset.Magnitude<=0.01 then return false end
  local hit=workspace:Raycast(origin,offset,rayParams)
  return hit~=nil and hit.Instance:IsDescendantOf(model)
 end
 for _,ch in ipairs(CollectionService:GetTagged('TrainingTarget')) do
  if ch and ch:IsA('Model') then
   local hum=ch:FindFirstChildOfClass('Humanoid')
   local selected=getTargetPart(ch)
   if hum and hum.Health>0 and selected and selected:IsA('BasePart') then
    local displacement=(ownRoot and ownRoot.Position or origin)-selected.Position
    if displacement.Magnitude<=options.MaxDistance and isVisible(selected,ch) then
     local projected=cam:WorldToViewportPoint(selected.Position)
     local dx,dy=projected.X-middle.X,projected.Y-middle.Y
     local pixels=math.sqrt(dx*dx+dy*dy)
     if projected.Z>0 and (options.Aim360 or pixels<=options.AimFov) then
      local score=options.Aim360 and displacement.Magnitude or pixels
      if score<bestScore then bestScore=score;bestPoint=selected.Position end
     end
     if projected.Z>0 and pixels<=options.TriggerFov and pixels<triggerScore then
      triggerPart=selected;triggerScore=pixels
     end
    end
   end
  end
 end
 if bestPoint then
  local origin=cam.CFrame.Position
  if (bestPoint-origin).Magnitude>.01 then
   local desired=CFrame.lookAt(origin,bestPoint)
   local aimResponse=45-options.AimSmooth
   local t=1-math.exp(-aimResponse*math.clamp(dt,0,.1))
   cam.CFrame=cam.CFrame:Lerp(desired,t)
  end
 end
 -- Only activate a compatible Tool if the selected body part is in the trigger
 -- radius AND a ray from the camera to that part is not blocked by a wall.
 if options.Triggerbot and (UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) or mobileTriggerHeld) and triggerPart and os.clock()-lastShot>=options.TriggerDelay then
  local origin=cam.CFrame.Position
  local offset=triggerPart.Position-origin
  if offset.Magnitude>.01 then
   local params=RaycastParams.new()
   params.FilterType=Enum.RaycastFilterType.Exclude
   params.FilterDescendantsInstances={player.Character}
   local hit=workspace:Raycast(origin,offset,params)
   local targetModel=triggerPart:FindFirstAncestorOfClass('Model')
   if hit and targetModel and hit.Instance:IsDescendantOf(targetModel) then
    local tool=player.Character and player.Character:FindFirstChildOfClass('Tool')
    if tool and tool.Enabled then
     lastShot=os.clock()
     tool:Activate()
    end
   end
  end
 end
end
local master=btn(panel,'Launch',{Position=UDim2.fromOffset(175,468),
 Size=UDim2.fromOffset(799,41),BackgroundColor3=C.surface,TextColor3=accent(),TextSize=14,ZIndex=23})
local status=label(panel,'READY  •  ALL MODULES OFF BY DEFAULT',10,C.muted,
 {Position=UDim2.fromOffset(180,516),Size=UDim2.new(1,-40,0,18),ZIndex=22})
local copyright=label(panel,'© 2026 Jx.studio. All rights reserved.',11,C.text,
 {Font=Enum.Font.GothamMedium,Position=UDim2.fromOffset(180,539),
 Size=UDim2.fromOffset(760,15),ZIndex=22,TextTransparency=.08})
local reopen=btn(gui,'✦ JX',{Position=UDim2.fromOffset(20,95),Size=UDim2.fromOffset(70,46),
 BackgroundColor3=C.surface,TextColor3=Color3.fromRGB(255,255,255),Visible=false,ZIndex=50})
stroke(reopen,ACCENT,1.5)
mk('UIGradient',reopen,{Rotation=35,Color=ColorSequence.new(C.surface,Color3.fromRGB(23,64,84))})
-- Persistent watermark; toggled independently from the overlay master switch.
local watermark=label(gui,'JX.STUDIO  •  VISUAL DEBUGGER',22,C.white,{
 Name='JxWatermark',Position=UDim2.fromOffset(23,75),
 Size=UDim2.fromOffset(410,38),ZIndex=60,
 Font=Enum.Font.GothamBlack,TextStrokeTransparency=.65})
local rainbow=mk('UIGradient',watermark,{Color=ColorSequence.new({
 ColorSequenceKeypoint.new(0,Color3.fromRGB(255,85,125)),
 ColorSequenceKeypoint.new(.25,Color3.fromRGB(255,218,85)),
 ColorSequenceKeypoint.new(.5,Color3.fromRGB(75,255,160)),
 ColorSequenceKeypoint.new(.75,Color3.fromRGB(80,170,255)),
 ColorSequenceKeypoint.new(1,Color3.fromRGB(255,85,235))})})
updateWatermark=function()
 watermark.Visible=alive and options.Watermark and not loading
end
updateWatermark()
local function setTab(n)
 section.Visible=(n=='esp');settings.Visible=(n=='settings');aimPane.Visible=(n=='aim')
 for key,pane in pairs(extraPanes) do pane.Visible=n==key end
 for key,button in pairs(tabButtons) do
  button.TextColor3=key==n and accent() or C.muted
  button.BackgroundColor3=key==n and Color3.fromRGB(25,49,68) or Color3.fromRGB(17,24,36)
  button.TextColor3=key==n and Color3.fromRGB(220,250,255) or C.muted
  local indicator=tabIndicators[key]
  if indicator then indicator.Visible=(key==n) end
 end
end
setTab('esp')
table.insert(connections,espTab.MouseButton1Click:Connect(function()setTab('esp')end))
table.insert(connections,settingsTab.MouseButton1Click:Connect(function()setTab('settings')end))
table.insert(connections,aimTab.MouseButton1Click:Connect(function()setTab('aim')end))
for _,id in ipairs({'weapons','movement','appearance','misc'}) do
 local tab=id
 table.insert(connections,tabButtons[id].MouseButton1Click:Connect(function()setTab(tab)end))
end
local function setEnabled(v)
 enabled=v;master.Text=v and 'Stop' or 'Launch'
 master.TextColor3=v and C.red or accent()
 status.Text=v and 'ACTIVE  •  FRAME-SYNCED RENDERING' or 'READY  •  OVERLAYS DISABLED'
 if not v then
  clear();cleanupFeatures();crosshair.Visible=false
 end
end
local function cleanup()
 if not alive then return end
 alive=false;enabled=false
 for _,c in ipairs(connections) do c:Disconnect() end
 cleanupFeatures();clear();blur:Destroy();gui:Destroy()
 if sharedEnv.JxStudioStop==cleanup then sharedEnv.JxStudioStop=nil end
end
sharedEnv.JxStudioStop=cleanup
table.insert(connections,master.MouseButton1Click:Connect(function()setEnabled(not enabled)end))
table.insert(connections,hideBtn.MouseButton1Click:Connect(function()
 minimized=true;panel.Visible=false;syncPanelShadow();reopen.Visible=true;blurState()
end))
table.insert(connections,reopen.MouseButton1Click:Connect(function()
 if movedJX then movedJX=false;return end
 minimized=false;panel.Visible=true;syncPanelShadow();reopen.Visible=false;blurState()
end))
table.insert(connections,closeBtn.MouseButton1Click:Connect(cleanup))
-- Keep switch labels translated after existing click handlers repaint them.
for _,node in ipairs(gui:GetDescendants()) do
 if node:IsA('TextButton') and node~=languageButton then
  table.insert(connections,node.MouseButton1Click:Connect(function()
   if options.Language=='Korean' then task.defer(refreshLanguage) end
  end))
 end
end
-- Movable compact JX restore button (drag moves it; click restores launcher).
local buttonDrag,buttonStart,buttonOrigin=false,nil,nil
local movedJX=false
table.insert(connections,reopen.InputBegan:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
  buttonDrag=true;movedJX=false;buttonStart=input.Position;buttonOrigin=reopen.Position
 end
end))
table.insert(connections,UIS.InputChanged:Connect(function(input)
 if buttonDrag and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
  local delta=input.Position-buttonStart
  if delta.Magnitude>5 then movedJX=true end
  reopen.Position=UDim2.new(buttonOrigin.X.Scale,buttonOrigin.X.Offset+delta.X,
   buttonOrigin.Y.Scale,buttonOrigin.Y.Offset+delta.Y)
 end
end))
table.insert(connections,UIS.InputEnded:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
  buttonDrag=false
 end
end))
-- Header dragging, mouse and touch.
local dragging,origin,startPosition=false,nil,nil
table.insert(connections,header.InputBegan:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
  dragging=true;origin=input.Position;startPosition=panel.Position
 end
end))
table.insert(connections,UIS.InputEnded:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
end))
table.insert(connections,UIS.InputChanged:Connect(function(input)
 if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
  local d=input.Position-origin
  panel.Position=UDim2.new(startPosition.X.Scale,startPosition.X.Offset+d.X,
   startPosition.Y.Scale,startPosition.Y.Offset+d.Y)
 end
end))
-- Run after camera updated. Never forcibly spin at 100Hz.
table.insert(connections,RS.RenderStepped:Connect(function(dt)
 fitPanel()
  if not alive or loading then return end
  rainbow.Offset=Vector2.new(math.sin(os.clock()*.7)*.8,0)
  local liveCam=workspace.CurrentCamera
  if enabled then featureUpdate(dt,liveCam) end
  if not enabled then fovCircle.Visible=false;triggerCircle.Visible=false;return end
 local cam=workspace.CurrentCamera;if not cam then return end
 aimUpdate(dt,cam)
 local view=cam.ViewportSize
 for _,p in ipairs(Players:GetPlayers()) do
  if p~=player then
   local v=visuals[p] or build(p)
   local ok,err=pcall(update,p,v,cam,view)
   if not ok then
    v.holder.Visible=false
    if not v.lastError or v.lastError~=tostring(err) then
     v.lastError=tostring(err)
     warn('[Jx.studio] Rendering '..p.Name..': '..tostring(err))
    end
   end
  end
 end
 for p,v in pairs(visuals) do
  if p.Parent~=Players then v.holder:Destroy();visuals[p]=nil end
 end
end))
-- Centered, non-fullscreen loader. Blur handles background dimming.
local loader=round(mk('Frame',gui,{Name='Loading',AnchorPoint=Vector2.new(.5,.5),
 Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(500,215),
 BackgroundColor3=C.bg,BorderSizePixel=0,ZIndex=80}),18)
stroke(loader,C.stroke,1.3)
mk('UIGradient',loader,{Rotation=90,Color=ColorSequence.new({
 ColorSequenceKeypoint.new(0,C.surface),ColorSequenceKeypoint.new(1,C.bg)})})
label(loader,'JX / STUDIO',28,C.text,{Font=Enum.Font.GothamBlack,
 Position=UDim2.fromOffset(25,23),Size=UDim2.fromOffset(430,45),ZIndex=81})
label(loader,'VISUAL DEBUGGER   /   PREPARING INTERFACE',10,accent(),
 {Position=UDim2.fromOffset(27,71),Size=UDim2.fromOffset(440,19),ZIndex=81})
local neonCopy=label(loader,'© 2026 Jx.studio. All rights reserved.',15,Color3.fromRGB(145,247,255),
 {Font=Enum.Font.GothamBold,Position=UDim2.fromOffset(27,105),Size=UDim2.fromOffset(445,25),ZIndex=81,
 TextStrokeColor3=ACCENT,TextStrokeTransparency=.62})
mk('UIGradient',neonCopy,{Color=ColorSequence.new(Color3.fromRGB(230,255,255),ACCENT)})
local track=round(mk('Frame',loader,{Position=UDim2.fromOffset(26,151),
 Size=UDim2.fromOffset(448,22),BackgroundColor3=C.card,BorderSizePixel=0,ZIndex=81}),11)
local fill=round(mk('Frame',track,{Size=UDim2.fromScale(0,1),
 BackgroundColor3=accent(),BorderSizePixel=0,ZIndex=82}),11)
local progress=label(loader,'LOADING  0%',10,C.muted,{Position=UDim2.fromOffset(27,179),
 Size=UDim2.fromOffset(440,19),ZIndex=81})
local start=os.clock()
local loadingConnection
loadingConnection=RS.Heartbeat:Connect(function()
 if not alive then loadingConnection:Disconnect();return end
 local fraction=math.clamp((os.clock()-start)/5,0,1)
 fill.Size=UDim2.fromScale(fraction,1)
 progress.Text=('LOADING  %d%%'):format(math.floor(100*fraction))
 if fraction>=1 then
  loadingConnection:Disconnect();loading=false;loader:Destroy();panel.Visible=true;syncPanelShadow();blurState();updateWatermark()
 end
end)
table.insert(connections,loadingConnection)
