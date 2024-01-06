{
  MIT License

  Copyright (c) 2024 Guilherme Freitas Nemeth

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
}

{$mode objfpc}{$H+}

unit WeTween;

interface

uses
  Classes, Generics.Defaults, Generics.Collections;

type
  TWeManager = class;

  TWeEasing = (
    weLinear,
    weEaseInSine,
    weEaseInQuad,
    weEaseInCubic,
    weEaseInQuart,
    weEaseOutSine,
    weEaseOutQuad,
    weEaseOutCubic,
    weEaseOutQuart
  );

  TWeInterpolateFunction = function (const X, A, B: Single): Single;

  TWeItem = class(TComponent)
  public
    Playing : Boolean;
    Position : Single;
    Duration : Single;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Update(); virtual;
  end;

  TWeTweenValueCallback = procedure (constref Vals: array of Single);
  TWeTweenValueObjectCallback = procedure (constref Vals: array of Single) of object;

  TWeTween = class(TWeItem)
  public
    Start : array[0..3] of Single;
    Stop : array[0..3] of Single;
    Values : array[0..3] of Single;
    Easing : TWeEasing;
    ValueCallback : TWeTweenValueCallback;
    ValueObjectCallback : TWeTweenValueObjectCallback;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Update(); override;

    { Return a new TWeTween that is the reverse of this tween }
    function Reverse: TWeTween;
  end;

  TWeEventCallback = procedure ();
  TWeEventObjectCallback = procedure () of object;

  TWeEvent = class(TWeItem)
  private
    fCallbackCalled : Boolean;

  public
    Callback : TWeEventCallback;
    ObjectCallback : TWeEventObjectCallback;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Update(); override;
  end;

  TWeTimelineItem = record
    Item : TWeItem;
    Offset : Single;
    Span : Single;
  end;

  TWeItemList = specialize TList<TWeItem>;
  TWeTimelineItemList = specialize TList<TWeTimelineItem>;

  TWeTimeline = class(TWeItem)
  private
    Items : TWeTimelineItemList;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Update(); override;

    procedure AdjustDuration();
    procedure InsertSpan(const Span: Single);
    procedure InsertAtEnd(T: TWeItem);
    function NewTweenAtEnd: TWeTween;
    function NewEventAtEnd: TWeEvent;
  end;

  TWeManager = class(TComponent)
  public
    RootTimeline : TWeTimeline;
    Items : TWeItemList;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Update(const SecondsPassed: Single);
  end;

  TWeTimelineItemComparer = class(TInterfacedObject, specialize IComparer<TWeTimelineItem>)
    function Compare(constref Left, Right: TWeTimelineItem): Integer;
  end;


function LinearLerp(const X, A, B: Single): Single;
function EaseInSineLerp(const X, A, B: Single): Single;
function EaseInQuadLerp(const X, A, B: Single): Single;
function EaseInCubicLerp(const X, A, B: Single): Single;
function EaseInQuartLerp(const X, A, B: Single): Single;
function EaseOutSineLerp(const X, A, B: Single): Single;
function EaseOutQuadLerp(const X, A, B: Single): Single;
function EaseOutCubicLerp(const X, A, B: Single): Single;
function EaseOutQuartLerp(const X, A, B: Single): Single;


var
  LerpFuncs : array[TWeEasing] of TWeInterpolateFunction;


implementation

uses
  SysUtils,
  Math;


constructor TWeItem.Create(AOwner: TComponent);
begin
  inherited;
  Position := 0;
  Duration := 0;
  Playing := false;
end;


destructor TWeItem.Destroy;
begin
  inherited;
end;


procedure TWeItem.Update();
begin
end;


constructor TWeTween.Create(AOwner: TComponent);
begin
  inherited;
  Easing := weLinear;
  ValueCallback := nil;
  ValueObjectCallback := nil;
end;


destructor TWeTween.Destroy;
begin
  inherited;
end;


function TWeTween.Reverse: TWeTween;
var
  I : Integer;
begin
  Result := TWeTween.Create(Self.Owner);
  Result.Duration := Duration;
  Result.Easing := Easing;

  for I := Low(Values) to High(Values) do
  begin
    Result.Start[I] := Stop[I];
    Result.Stop[I] := Start[I];
  end;
end;


procedure TWeTween.Update();
var
  I : Integer;
  X : Single;
begin
  inherited;

  if not Playing then Exit;

  X := Position / Duration;

  for I := Low(Values) to High(Values) do
  begin
    Values[I] := LerpFuncs[Easing](X, Start[I], Stop[I]);
  end;

  if ValueCallback <> nil then
    ValueCallback(Values);

  if ValueObjectCallback <> nil then
    ValueObjectCallback(Values);
end;


constructor TWeEvent.Create(AOwner: TComponent);
begin
  inherited;
  Callback := nil;
end;


destructor TWeEvent.Destroy;
begin
  inherited;
end;


procedure TWeEvent.Update();
begin
  if Position <= 0.0 then
    fCallbackCalled := false;

  if Playing and (not fCallbackCalled) then
  begin
    if Callback <> nil then Callback();
    if ObjectCallback <> nil then ObjectCallback();
    fCallbackCalled := true;
  end;
end;


constructor TWeTimeline.Create(AOwner: TComponent);
begin
  inherited;
  Items := TWeTimelineItemList.Create;
end;


destructor TWeTimeline.Destroy;
begin
  FreeAndNil(Items);
  inherited;
end;


function TWeTimelineItemComparer.Compare(constref Left, Right: TWeTimelineItem): Integer;
begin
  Result := Round(Left.Offset*1000 - Right.Offset*1000);
end;


procedure TWeTimeline.AdjustDuration();
var
  Item : TWeTimelineItem;
  ChildTimeline : TWeTimeline;
begin
  Duration := 0;
  for Item in Items do
  begin
    Duration := Duration + Item.Span;
    if Item.Item <> nil then
    begin
      if Item.Item is TWeTimeline then
      begin
        ChildTimeline := TWeTimeline(Item.Item);
        ChildTimeline.AdjustDuration();
      end;
      Duration := Duration + Item.Item.Duration;
    end;
  end;
end;


procedure TWeTimeline.Update();
var
  Comp : TWeTimelineItemComparer;
  Item : TWeTimelineItem;
begin
  inherited;

  if not Playing then Exit;

  Comp := TWeTimelineItemComparer.Create;
  Items.Sort(Comp);
  FreeAndNil(Comp);

  for Item in Items do
  begin
    if Item.Item <> nil then
    begin
      Item.Item.Position := Position - Item.Offset;

      if Item.Item is TWeEvent then
        Item.Item.Playing := (Item.Item.Position > 0.0)
      else
        Item.Item.Playing := (Item.Item.Position > 0.0) and (Item.Item.Position < Item.Item.Duration);

      Item.Item.Update();
    end;
  end;
end;


procedure TWeTimeline.InsertSpan(const Span: Single);
var
  NewItem : TWeTimelineItem;
begin
  AdjustDuration();
  NewItem.Offset := Duration;
  NewItem.Span := Span;
  Duration := Duration + Span;
  Items.Add(NewItem);
end;


procedure TWeTimeline.InsertAtEnd(T: TWeItem);
var
  NewItem : TWeTimelineItem;
begin
  AdjustDuration();
  NewItem.Item := T;
  NewItem.Offset := Duration;
  Duration := Duration + T.Duration;
  Items.Add(NewItem);
end;


function TWeTimeline.NewTweenAtEnd: TWeTween;
begin
  Result := TWeTween.Create(Self);
  InsertAtEnd(Result);
end;


function TWeTimeline.NewEventAtEnd: TWeEvent;
begin
  Result := TWeEvent.Create(Self);
  InsertAtEnd(Result);
end;


constructor TWeManager.Create(AOwner: TComponent);
begin
  inherited;
  RootTimeline := TWeTimeline.Create(Self);
  Items := TWeItemList.Create;
  Items.Add(RootTimeline);
end;


destructor TWeManager.Destroy;
begin
  inherited;
  FreeAndNil(Items);
end;


procedure TWeManager.Update(const SecondsPassed: Single);
var
  Item : TWeItem;
begin
  for Item in Items do
  begin
    Item.Position := Item.Position + SecondsPassed;

    if Item is TWeTimeline then
      TWeTimeline(Item).AdjustDuration();

    Item.Update();
  end;
end;


function LinearLerp(const X, A, B: Single): Single;
begin
  Result := A + X * (B - A);
end;


function EaseInSineLerp(const X, A, B: Single): Single;
begin
  Result := A + (1 - Cos((X * PI) / 2)) * (B - A);
end;


function EaseInQuadLerp(const X, A, B: Single): Single;
begin
  Result := A + (X * X) * (B - A);
end;


function EaseInCubicLerp(const X, A, B: Single): Single;
begin
  Result := A + (X * X * X) * (B - A);
end;


function EaseInQuartLerp(const X, A, B: Single): Single;
begin
  Result := A + (X * X * X * X) * (B - A);
end;


function EaseOutSineLerp(const X, A, B: Single): Single;
begin
  Result := A + (Sin((X * PI) / 2)) * (B - A);
end;


function EaseOutQuadLerp(const X, A, B: Single): Single;
begin
  Result := A + (1 - (1 - x) * (1 - x)) * (B - A);
end;


function EaseOutCubicLerp(const X, A, B: Single): Single;
begin
  Result := A + (1 - Power(1 - x, 3)) * (B - A);
end;


function EaseOutQuartLerp(const X, A, B: Single): Single;
begin
  Result := A + (1 - Power(1 - x, 4)) * (B - A);
end;


initialization

  LerpFuncs[weLinear] := @LinearLerp;
  LerpFuncs[weEaseInSine] := @EaseInSineLerp;
  LerpFuncs[weEaseInQuad] := @EaseInQuadLerp;
  LerpFuncs[weEaseInCubic] := @EaseInCubicLerp;
  LerpFuncs[weEaseInQuart] := @EaseInQuartLerp;
  LerpFuncs[weEaseOutSine] := @EaseOutSineLerp;
  LerpFuncs[weEaseOutQuad] := @EaseOutQuadLerp;
  LerpFuncs[weEaseOutCubic] := @EaseOutCubicLerp;
  LerpFuncs[weEaseOutQuart] := @EaseOutQuartLerp;

end.
