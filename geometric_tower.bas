'$Include:'include\vector\vector.bi'
Dim Shared As Vec2 Camera, FinalCamera, MapOffset
Const W = 400
Const H = 225

Const WorldSize = 1024

Randomize Timer

Type Tower
    As Vec2 Position
    As _Unsigned Long TargetEnemy, TotalCost
    As Single FireRadius, TowerSize, TargetAngle, MaxTurnRate
    As Long Health, MaxHealth, SelfHeal
    As Single Angle
    'Energy - for shields
    As Single RadiusTheta
    As _Unsigned Integer FireDelay, LastFireTick, LastIdleTick, LastHealTick
    As _Unsigned _Byte TargetAcquired, Alive, Level
End Type
Const CONST_TOWER_COST = 30
Dim Shared As Tower Towers(0 To 255)

Type Enemy
    As _Unsigned _Byte Type
    As Vec2 Position
    As Single Angle
    As Single Speed
    As _Unsigned _Byte Target, LastFireTick
    As Integer Health, MaxHealth
    As _Unsigned _Byte Alive
End Type
Dim Shared As Enemy Enemies(0 To 1023)

Const BULLET_TOWER = 1
Const BULLET_ENEMY = 2

Dim Shared Money As Long
Money = 1000 + CONST_TOWER_COST

'First Run
NewTower 0, 0

_Delay 0.5
Screen _NewImage(W, H, 32)
Color -1, 0
_Title "Geometry Tower"
_FullScreen _SquarePixels

Dim Shared As _Unsigned Long Background, Enemy_One, Enemy_Two, Enemy_Four, Enemy_Five, Enemy_Six
Background = _LoadImage("res\0001.png", 32)
Enemy_One = _LoadImage("res\0002.png", 32)
Enemy_Two = _LoadImage("res\0003.png", 32)
Enemy_Four = _LoadImage("res\0004.png", 32)
Enemy_Five = _LoadImage("res\0005.png", 32)
Enemy_Six = _LoadImage("res\0006.png", 32)

Dim As Vec2 oldMouse, ScreenCoords: Dim Shared As _Unsigned Integer TowerSelected

Const MenuW = W - 128

EnemyCreateTime = 60

Do
    Cls , _RGB32(183, 155, 111)
    _Limit 60
    While _MouseInput
        If _MouseButton(1) Then
            FinalCamera.X = FinalCamera.X - _MouseX + oldMouse.X
            FinalCamera.Y = FinalCamera.Y - _MouseY + oldMouse.Y
        End If
        ScrollOffset = Clamp(0, ScrollOffset + _MouseWheel, 255)
    Wend
    oldMouse.X = _MouseX
    oldMouse.Y = _MouseY
    ScreenCoords.X = _MouseX + Camera.X
    ScreenCoords.Y = _MouseY + Camera.Y
    If _MouseButton(1) And InRange(0, oldMouse.X, IIF(TowerSelected, MenuW, W)) Then
        For I = LBound(Towers) To UBound(Towers)
            If Vec2Dis(Towers(I).Position, ScreenCoords) < Towers(I).TowerSize And (Towers(I).Alive Or Towers(I).Level) Then
                TowerSelected = I + 1
                FinalCamera.X = Towers(I).Position.X + 64
                FinalCamera.Y = Towers(I).Position.Y
                Exit For
            End If
        Next I
    End If
    RefreshCamera
    For X = 0 To _Width + 16 Step 16
        For Y = 0 To _Height + 16 Step 16
            _PutImage (X - MapOffset.X, Y - MapOffset.Y)-(X - MapOffset.X + 16, Y - MapOffset.Y + 16), Background
    Next Y, X
    If LastEnemyCreateTime = 0 Then
        CreateEnemy
        LastEnemyCreateTime = Int(EnemyCreateTime)
        EnemyCreateTime = EnemyCreateTime + 0.01 * Sgn(15 - EnemyCreateTime)
    Else
        LastEnemyCreateTime = LastEnemyCreateTime - 1
    End If
    Select Case _KeyHit
        Case 27: Exit Do
        Case 78, 110: If Money >= 25 Then NewTower ScreenCoords.X, ScreenCoords.Y
    End Select
    SimulateTowers
    SimulateEnemies
    SimulateBullets 0, 0, 0, 0
    If TowerSelected Then 'Show Menu
        Line (MenuW, 0)-(_Width - 1, _Height - 1), _RGB32(0, 63), BF
        _PrintString (W - 8, 0), "X"
        _PrintString (MenuW, 0), Chr$(17) 'Left
        _PrintString (W - 24, 0), Chr$(16) 'Right
        TS = TowerSelected - 1
        _PrintString (MenuW, 0), "   Tower" + Str$(TS)
        Select Case Page
            Case 0
                _PrintString (MenuW, 16), "Level:" + Str$(Towers(TS).Level)
                Line (MenuW, 31)-(W, 31), _RGB32(255)
                Health! = Towers(TS).Health / Towers(TS).MaxHealth
                Line (MenuW, 31)-(MenuW + 128 * Health!, 31), _RGB32(255 * (1 - Health!), 255 * Health!, 0)
                _PrintString (MenuW, 32), "   Statistics"
                _PrintString (MenuW, 48), "Health:" + _Trim$(Str$(Towers(TS).Health))
                _PrintString (MenuW, 64), "Max Health:" + _Trim$(Str$(Towers(TS).MaxHealth))
                _PrintString (MenuW, 80), "Turn Rate:" + _Trim$(Str$(Towers(TS).MaxTurnRate))
                _PrintString (MenuW, 96), "Fire Speed:" + _Trim$(Str$(59 - Towers(TS).FireDelay))
                _PrintString (MenuW, 112), "Fire Radius:" + _Trim$(Str$(Towers(TS).FireRadius))
                _PrintString (MenuW, 128), "      Costs"
                _PrintString (MenuW, 144), "Self Heal:" + _Trim$(Str$(Towers(TS).SelfHeal))
                _PrintString (MenuW, 160), "Worth:" + _Trim$(Str$(Towers(TS).TotalCost))
                If Towers(TS).Alive Then
                    If Towers(TS).Level < 100 Then RequiredMoney = 5 + 5 * Towers(TS).Level
                    HealMoney = Ceil((Towers(TS).MaxHealth - Towers(TS).Health) / 10)
                    Line (MenuW, 176)-(W, 224), _RGB32(0, 63), BF
                    _PrintString (MenuW, 176), "Heal:" + _Trim$(Str$(HealMoney))
                    _PrintString (MenuW, 192), "Sell:" + _Trim$(Str$(Towers(TS).TotalCost * 0.6))
                    If Towers(TS).Level < 100 Then _PrintString (MenuW, 208), "Upgrade:" + _Trim$(Str$(RequiredMoney))
                    If InRange(MenuW, oldMouse.X, W) And _MouseButton(1) Then
                        If InRange(176, oldMouse.Y, 191) And Money >= HealMoney Then
                            While _MouseButton(1) Or _MouseInput: Wend
                            Towers(TS).Health = Towers(TS).MaxHealth
                            Money = Money - HealMoney
                        ElseIf InRange(192, oldMouse.Y, 207) Then
                            While _MouseButton(1) Or _MouseInput: Wend
                            Towers(TS).Alive = 0
                            Towers(TS).Level = 0
                            Money = Money + Towers(TS).TotalCost * 0.6
                        ElseIf InRange(208, oldMouse.Y, 224) And Money >= RequiredMoney And Towers(TS).Level < 100 Then
                            While _MouseButton(1) Or _MouseInput: Wend
                            Towers(TS).MaxTurnRate = Towers(TS).MaxTurnRate - Sgn(Towers(TS).MaxTurnRate - 60)
                            Towers(TS).MaxHealth = 100 + 10 * Towers(TS).Level
                            Towers(TS).Health = Towers(TS).Health + 10
                            Towers(TS).FireRadius = Towers(TS).FireRadius + 1
                            Towers(TS).FireDelay = Towers(TS).FireDelay - Sgn(Towers(TS).FireDelay)
                            Towers(TS).Level = Towers(TS).Level + 1
                            Towers(TS).SelfHeal = Towers(TS).SelfHeal - ((Towers(TS).Level Mod 5) = 0)
                            Towers(TS).TotalCost = Towers(TS).TotalCost + RequiredMoney
                            Money = Money - RequiredMoney
                        End If
                    End If
                Else
                    RequiredMoney = Max(CONST_TOWER_COST + 10 * Towers(TS).Level, Towers(TS).TotalCost * 0.9)
                    _PrintString (MenuW, 192), _Trim$(Str$(RequiredMoney))
                    Line (MenuW, 208)-(W, 224), _RGB32(0, 63), BF
                    _PrintString (MenuW, 208), "     Repair"
                    If InRange(208, oldMouse.Y, 224) And _MouseButton(1) Then
                        While _MouseButton(1) Or _MouseInput: Wend
                        Towers(TS).Health = Towers(TS).MaxHealth
                        Towers(TS).Alive = -1
                        Money = Money - RequiredMoney
                    End If
                End If
            Case 1
                Dim As _Unsigned _Bit * 2 Page2X
                Dim As _Unsigned _Byte Page2Y
                Page2X = 0
                Page2Y = 0
                For I = ScrollOffset To 4 * 12 + ScrollOffset
                    If InRange(0, I, 255) = 0 Then _Continue
                    If Towers(I).Alive = 0 And Towers(I).Level = 0 Then _Continue
                    If Towers(I).Alive Then
                        Health! = Towers(TS).Health / Towers(TS).MaxHealth: Color -1, _RGB32(255 * (1 - Health!), 255 * Health!, 0)
                    Else Color -1, _RGB32(127)
                    End If
                    _PrintString (MenuW + Page2X * 32, 32 + Page2Y * 16), _Trim$(Str$(I))
                    If _MouseButton(1) And InRange(MenuW + Page2X * 32, oldMouse.X, MenuW + Page2X * 32 + 32) And InRange(Page2Y * 16 + 32, oldMouse.Y, Page2Y * 16 + 48) Then
                        TowerSelected = I + 1
                        FinalCamera.X = Towers(I).Position.X + 64
                        FinalCamera.Y = Towers(I).Position.Y
                        Page = 0
                    End If
                    Page2X = Page2X + 1
                    Page2Y = Page2Y - (Page2X = 0)
                Next I
                Color -1, 0
        End Select
        If _MouseButton(1) And InRange(0, oldMouse.Y, 16) Then
            If InRange(W - 8, oldMouse.X, W) Then TowerSelected = 0: FinalCamera.X = FinalCamera.X - 64
            If InRange(MenuW, oldMouse.X, MenuW + 7) And TowerSelected > 0 Then
                Do: TowerSelected = ClampCycle(1, TowerSelected - 1, 256): Loop Until Towers(TowerSelected - 1).Alive Or Towers(TowerSelected - 1).Level
                FinalCamera.X = Towers(TowerSelected - 1).Position.X + 64
                FinalCamera.Y = Towers(TowerSelected - 1).Position.Y
                While _MouseInput Or _MouseButton(1): Wend
            End If
            If InRange(MenuW + 8, oldMouse.X, W - 23) Then Page = 1
            If InRange(W - 24, oldMouse.X, W - 16) And TowerSelected < 255 Then
                Do: TowerSelected = ClampCycle(1, TowerSelected + 1, 256): Loop Until Towers(TowerSelected - 1).Alive Or Towers(TowerSelected - 1).Level
                FinalCamera.X = Towers(TowerSelected - 1).Position.X + 64
                FinalCamera.Y = Towers(TowerSelected - 1).Position.Y
                While _MouseInput Or _MouseButton(1): Wend
            End If
        End If
    Else Page = 0
    End If
    _PrintString (144, 0), "Geometry Tower"
    Print "Money:"; _Trim$(Str$(Money))
    _Display
Loop
System
Sub NewTower (X As Integer, Y As Integer)
    Static As _Unsigned _Byte NewTowerID
    If Towers(NewTowerID).Alive Then
        For I = LBound(Towers) To UBound(Towers)
            If Towers(I).Alive Then NewTowerID = I: Exit For
        Next I
        If I = UBound(Towers) + 1 Then Exit Sub
    End If
    NewVec2 Towers(NewTowerID).Position, X, Y
    Towers(NewTowerID).Angle = Rnd * 360
    Towers(NewTowerID).MaxTurnRate = 6
    Towers(NewTowerID).MaxHealth = 100
    Towers(NewTowerID).Health = Towers(NewTowerID).MaxHealth
    Towers(NewTowerID).FireRadius = 50
    Towers(NewTowerID).FireDelay = 59
    Towers(NewTowerID).LastFireTick = 0
    Towers(NewTowerID).Alive = -1
    Towers(NewTowerID).Level = 1
    Towers(NewTowerID).TotalCost = CONST_TOWER_COST
    NewTowerID = NewTowerID + 1
    Money = Money - CONST_TOWER_COST
End Sub
Sub SimulateTowers
    For I = LBound(Towers) To UBound(Towers)
        If Towers(I).Alive = 0 Then
            If Towers(I).Level = 0 Then _Continue
            TX = Towers(I).Position.X - Camera.X
            TY = Towers(I).Position.Y - Camera.Y
            For R = Towers(I).TowerSize To Towers(I).TowerSize * 2: Circle (TX, TY), R, _RGB32(127): Next R
            Line (TX, TY)-(TX + 10 * Cos(_D2R(Towers(I).Angle)), TY + 10 * Sin(_D2R(Towers(I).Angle))), _RGB32(191)
            _Continue
        End If
        If Towers(I).TargetAcquired And Enemies(Towers(I).TargetEnemy).Alive = 0 Then Towers(I).TargetAcquired = 0
        If Towers(I).TargetAcquired = 0 Or Vec2Dis(Enemies(Towers(I).TargetEnemy).Position, Towers(I).Position) > Towers(I).FireRadius Then
            MinDisEnemy = Towers(I).FireRadius
            For J = LBound(Enemies) To UBound(Enemies)
                If Enemies(J).Alive = 0 Then _Continue
                D! = Vec2Dis(Towers(I).Position, Enemies(J).Position)
                If D! < MinDisEnemy Then
                    MinDisEnemy = D!
                    Towers(I).TargetEnemy = J
                    Towers(I).TargetAcquired = -1
                End If
            Next J
        End If
        If Towers(I).TargetAcquired Then Towers(I).TargetAngle = ClampCycleDifference(0, _R2D(Vec2Angle(Towers(I).Position, Enemies(Towers(I).TargetEnemy).Position)), 359)
        Towers(I).Angle = TransitAngle(Towers(I).Angle, Towers(I).TargetAngle, Towers(I).MaxTurnRate)
        If Enemies(Towers(I).TargetEnemy).Alive And Abs(Towers(I).Angle - Towers(I).TargetAngle) < 6 And Towers(I).TargetAcquired Then
            If Towers(I).LastFireTick = 0 Then
                Towers(I).LastFireTick = Towers(I).FireDelay
                SimulateBullets BULLET_TOWER, Towers(I).Position.X, Towers(I).Position.Y, Towers(I).Angle
            Else
                Towers(I).LastFireTick = Towers(I).LastFireTick - 1
            End If
        Else
            If Towers(I).LastIdleTick = 0 Then
                Towers(I).LastIdleTick = 120
                Towers(I).TargetAngle = Rnd * 360
            Else
                Towers(I).LastIdleTick = Towers(I).LastIdleTick - 1
            End If
        End If
        If Towers(I).LastHealTick = 0 Then
            Towers(I).LastHealTick = 60
            Towers(I).Health = Min(Towers(I).Health + Towers(I).SelfHeal, Towers(I).MaxHealth)
        Else
            Towers(I).LastHealTick = Towers(I).LastHealTick - 1
        End If
        TX = Towers(I).Position.X - Camera.X
        TY = Towers(I).Position.Y - Camera.Y
        'Tower
        Select Case Towers(I).Level
            Case 1 To 20: Towers(I).TowerSize = Ceil(Towers(I).FireRadius / 20) - 0
            Case 21 To 40: Towers(I).TowerSize = Ceil(Towers(I).FireRadius / 20) - 1
            Case 41 To 60: Towers(I).TowerSize = Ceil(Towers(I).FireRadius / 20) - 2
            Case 61 To 80: Towers(I).TowerSize = Ceil(Towers(I).FireRadius / 20) - 3
            Case 81 To 100: Towers(I).TowerSize = Ceil(Towers(I).FireRadius / 20) - 4
        End Select
        Select Case Int(Towers(I).Level / 10)
            Case 0: TowerColour& = _RGB32(0, 127, 255)
            Case 1: TowerColour& = _RGB32(0, 191, 127)
            Case 2: TowerColour& = _RGB32(0, 255, 127)
            Case 3: TowerColour& = _RGB32(127, 255, 0)
            Case 4: TowerColour& = _RGB32(255, 127, 0)
            Case 5: TowerColour& = _RGB32(255, 0, 127)
            Case 6: TowerColour& = _RGB32(127, 0, 255)
            Case 7: TowerColour& = _RGB32(191, 0, 255)
            Case 8: TowerColour& = _RGB32(0, 0, 255)
            Case 9: TowerColour& = _RGB32(0, 255, 0)
            Case 10: TowerColour& = _RGB32(255, 0, 0)
        End Select
        For R = Towers(I).TowerSize To Towers(I).TowerSize * 2: Circle (TX, TY), R, TowerColour&: Next R
        'Angle Line
        Line (TX, TY)-(TX + 10 * Cos(_D2R(Towers(I).Angle)), TY + 10 * Sin(_D2R(Towers(I).Angle))), -1
        'Health Bar
        Health! = 3 * Towers(I).Health / Towers(I).MaxHealth
        Line (TX - 10, TY - Towers(I).TowerSize - 9)-(TX + 10, TY - Towers(I).TowerSize - 7), -1, BF 'Outer Box
        Health1! = Clamp(0, Health!, 1) - 0
        Health2! = Clamp(1, Health!, 2) - 1
        Health3! = Clamp(2, Health!, 3) - 2
        Line (TX - 10, TY - Towers(I).TowerSize - 9)-(TX - 10 + 20 * Health1!, TY - Towers(I).TowerSize - 9), _RGB32(255 * (1 - Health1!), 255 * Health1!, 0)
        If Health2! Then Line (TX - 10, TY - Towers(I).TowerSize - 8)-(TX - 10 + 20 * Health2!, TY - Towers(I).TowerSize - 8), _RGB32(255 * (1 - Health2!), 255 * Health2!, 0)
        If Health3! Then Line (TX - 10, TY - Towers(I).TowerSize - 7)-(TX - 10 + 20 * Health3!, TY - Towers(I).TowerSize - 7), _RGB32(255 * (1 - Health3!), 255 * Health3!, 0)
        If I + 1 = TowerSelected Then
            DotCircle TX, TY, Towers(I).FireRadius, TowerColour&
        Else
            Circle (TX, TY), Towers(I).FireRadius, _RGBA(255, 255, 255, 63) And TowerColour&
        End If
    Next I
End Sub
Sub CreateEnemy
    Static As _Unsigned _Bit * 10 NewEnemyID
    Static As Single Hardness, EntityHealthHardness, EntitySpeedHardness
    Hardness = Min(Hardness + 0.01, 4.99)
    EntityHealthHardness = EntityHealthHardness + 0.0001
    EntitySpeedHardness = EntitySpeedHardness + 0.0001
    If Enemies(NewEnemyID).Alive Then
        For I = LBound(Enemies) To UBound(Enemies)
            If Enemies(I).Alive Then NewEnemyID = I: Exit For
        Next I
        If I = UBound(Enemies) + 1 Then Exit Sub
    End If
    Enemies(NewEnemyID).Type = Int(Rnd * Int(1 + Hardness)) + 1
    NewVec2 Enemies(NewEnemyID).Position, Rand * WorldSize, Rand * WorldSize
    MinDis = WorldSize
    For I = LBound(Towers) To UBound(Towers)
        If Towers(I).Alive = 0 Then _Continue
        D! = Vec2Dis(Towers(I).Position, Enemies(NewEnemyID).Position)
        If D! < MinDis Then
            MinDis = D!
            MinDisTarget = I
            MinDisAngle = _R2D(Vec2Angle(Enemies(NewEnemyID).Position, Towers(I).Position))
        End If
    Next I
    Enemies(NewEnemyID).Angle = MinDisAngle
    Enemies(NewEnemyID).Speed = 0.2 - Enemies(NewEnemyID).Type / 6 + EntitySpeedHardness
    Enemies(NewEnemyID).Target = MinDisTarget
    Enemies(NewEnemyID).MaxHealth = Enemies(NewEnemyID).Type + EntityHealthHardness
    Enemies(NewEnemyID).Health = Enemies(NewEnemyID).MaxHealth
    Enemies(NewEnemyID).Alive = -1
    NewEnemyID = NewEnemyID + 1
End Sub
Sub SimulateEnemies
    For I = LBound(Enemies) To UBound(Enemies)
        Enemies(I).Alive = Enemies(I).Health > 0
        If Enemies(I).Alive = 0 Then _Continue
        EX = Enemies(I).Position.X
        EY = Enemies(I).Position.Y

        'Search for targets
        MinDis = WorldSize
        For J = LBound(Towers) To UBound(Towers)
            If Towers(J).Alive = 0 Then _Continue
            D! = Vec2Dis(Towers(J).Position, Enemies(I).Position)
            If D! < MinDis Then
                MinDis = D!
                MinDisTarget = J
                MinDisAngle = _R2D(Vec2Angle(Enemies(I).Position, Towers(J).Position))
            End If
        Next J
        Enemies(I).Target = MinDisTarget
        Enemies(I).Angle = MinDisAngle

        If Towers(Enemies(I).Target).Alive Then
            Select Case Vec2Dis(Enemies(I).Position, Towers(Enemies(I).Target).Position)
                Case Is < Towers(Enemies(I).Target).TowerSize + 8
                    If Enemies(I).LastFireTick = 0 Then
                        SimulateBullets BULLET_ENEMY, Enemies(I).Position.X, Enemies(I).Position.Y, _R2D(Vec2Angle(Enemies(I).Position, Towers(Enemies(I).Target).Position))
                        Enemies(I).LastFireTick = 48 - Enemies(I).Type
                    Else
                        Enemies(I).LastFireTick = Enemies(I).LastFireTick - 1
                    End If
                Case Is < 4096
                    Enemies(I).Position.X = EX + Enemies(I).Speed * Cos(_D2R(Enemies(I).Angle))
                    Enemies(I).Position.Y = EY + Enemies(I).Speed * Sin(_D2R(Enemies(I).Angle))
            End Select
        End If
        EX = EX - Camera.X
        EY = EY - Camera.Y
        Select Case Enemies(I).Type
            Case 1 'Triangle
                _PutImage (EX - 8, EY - 8), Enemy_One
            Case 2 'Square
                _PutImage (EX - 8, EY - 8), Enemy_Two
            Case 3 'Circle
                Circle (EX, EY), 4, _RGB32(255, 0, 0)
            Case 4 'Pentagon
                _PutImage (EX - 8, EY - 8), Enemy_Four
            Case 5 'Hexagon
                _PutImage (EX - 8, EY - 8), Enemy_Five
        End Select
    Next I
End Sub
Sub SimulateBullets (F As _Byte, X As Integer, Y As Integer, T As Single)
    Type Bullet
        As Vec2 Position, Velocity
        As Single Angle
        As Single Speed
        As _Unsigned _Byte Owner
        As _Unsigned _Byte Alive
    End Type
    Static As Bullet Bullets(0 To 1023)
    Static As _Unsigned _Bit * 10 NewBulletID
    Static As Vec2 V
    If F Then
        Bullets(NewBulletID).Position.X = X
        Bullets(NewBulletID).Position.Y = Y
        Bullets(NewBulletID).Angle = T
        Bullets(NewBulletID).Speed = 10
        NewVec2 Bullets(NewBulletID).Velocity, Cos(_D2R(T)), Sin(_D2R(T))
        Vec2Multiply Bullets(NewBulletID).Velocity, Bullets(NewBulletID).Speed
        Bullets(NewBulletID).Owner = F
        Bullets(NewBulletID).Alive = -1
        NewBulletID = NewBulletID + 1
    Else
        For I = 0 To 1023
            If Bullets(I).Alive = 0 Then _Continue
            Select Case Bullets(I).Owner
                Case BULLET_ENEMY
                    For J = LBound(Towers) To UBound(Towers)
                        If Towers(J).Alive And Vec2Dis(Bullets(I).Position, Towers(J).Position) < 20 Then
                            Towers(J).Health = Towers(J).Health - 1
                            Towers(J).Alive = Towers(J).Health <> 0
                            Bullets(I).Alive = 0
                            Exit For
                        End If
                    Next J
                Case BULLET_TOWER
                    For J = LBound(Enemies) To UBound(Enemies)
                        If Enemies(J).Alive And Vec2Dis(Bullets(I).Position, Enemies(J).Position) < 5 Then
                            Enemies(J).Health = Enemies(J).Health - 1
                            Enemies(J).Alive = Enemies(J).Health <> 0
                            Money = Money - (Enemies(J).Health = 0) * Enemies(J).Type * Enemies(J).MaxHealth
                            Bullets(I).Alive = 0
                            Exit For
                        End If
                    Next J
            End Select
            If Bullets(I).Alive = 0 Then _Continue
            V = Bullets(I).Position
            Vec2Add Bullets(I).Position, Bullets(I).Velocity
            Line (Bullets(I).Position.X - Camera.X, Bullets(I).Position.Y - Camera.Y)-(V.X - Camera.X, V.Y - Camera.Y), _RGB32(0)
        Next I
    End If
End Sub
Sub DotCircle (X As Integer, Y As Integer, R As Single, __C&)
    Static As Single __X1, __Y1
    For I = 0 To 360 Step 2
        __C! = Cos(_D2R(I))
        __S! = Sin(_D2R(I))
        __X1 = X + R * __C!
        __Y1 = Y + R * __S!
        PSet (__X1, __Y1), __C&
    Next I
End Sub
Sub RefreshCamera
    Camera.X = Camera.X + (FinalCamera.X - Camera.X - W / 2) / 8
    Camera.Y = Camera.Y + (FinalCamera.Y - Camera.Y - H / 2) / 8
    MapOffset.X = ModFloor(Camera.X, 16)
    MapOffset.Y = ModFloor(Camera.Y, 16)
End Sub
Function Rand!
    Rand! = Rnd - 0.5
End Function
Function Ceil& (X#)
    Ceil& = Int(X#) + Sgn(X# - Int(X#))
End Function
'$Include:'include\vector\vector.bm'
'$Include:'include\min.bm'
'$Include:'include\max.bm'
'$Include:'include\clamp.bm'
'$Include:'include\inrange.bm'
'$Include:'include\transitangle.bm'
'$Include:'include\modfloor.bm'
'$Include:'include\iif.bm'
