# wetween
A basic tweening/animation library for Free Pascal.

## Example usage

```pascal

var
  Tweens: TWeManager;
  RotationTween: TWeTween;
  RotationEndedEvent: TWeEvent;
  ReverseRotationTween: TWeTween;
  SecondsPassed: Single;

  MyRotationAngle: Single;

  procedure SetTweenRotation(constref Values: array of Single);
  begin
    MyRotationAngle := Values[0];
  end;

begin
  Tweens := TWeManager.Create(Self);

  RotationTween := Tweens.RootTimeline.NewTweenAtEnd;
  RotationTween.Start[0] := 0.0;
  RotationTween.Stop[0] := -PI/2.0;
  RotationTween.Duration := 0.5;
  RotationTween.Easing := weEaseInQuart;
  RotationTween.ValueCallback := @SetTweenRotation;

  RotationEndedEvent := Tweens.RootTimeline.NewEventAtEnd;
  RotationEndedEvent.ObjectCallback := @DoAttack;

  ReverseRotationTween := AttackRotationTween.Reverse;
  ReverseRotationTween.ValueCallback := @SetTweenRotation;
  Tweens.RootTimeline.InsertAtEnd(ReverseRotationTween);

  Tweens.RootTimeline.Playing := true;

  { Some main loop (i.e. in a game engine) }

  while true do
  begin
    SecondsPassed := GetSecondsPassed();
    Tweens.Update(SecondsPassed);
  end;
end.
```

## LICENSE

MIT