unit u_MapNalLayer;

interface

uses
  Windows,
  GR32,
  GR32_Image,
  GR32_Polygons,
  t_GeoTypes,
  u_MapViewPortState,
  u_MapLayerBasic;

type
  TMapNalDrawType = (mndtNothing, mndtSelectRect, mndtSelectPoly, mndtCalcLen, mndtNewPath, mndtNewPoly);

  TMapNalLayer = class(TMapLayerBasic)
  private
    FDrawType: TMapNalDrawType;
    FPath: TExtendedPointArray;
    FSelectedLonLat: TExtendedRect;
    FPolyActivePointIndex: integer;
    FLenShow: Boolean;

    FPolyPointColor: TColor32;
    FPolyActivePointColor: TColor32;
    FPolyFirstPointColor: TColor32;
    FPolyLineColor: TColor32;
    FPolyFillColor: TColor32;
    FPolyLineWidth: Integer;
    FCalcLineColor: TColor32;
    FCalcTextColor: TColor32;
    FCalcTextBGColor: TColor32;
    FCalcPointFillColor: TColor32;
    FCalcPointRectColor: TColor32;
    FCalcPointFirstColor: TColor32;
    FCalcPointActiveColor: TColor32;
    FSelectionPolyFillColor: TColor32;
    FSelectionPolyBorderColor: TColor32;
    FSelectionPolyPointFirstColor: TColor32;
    FSelectionPolyPointColor: TColor32;
    FSelectionRectFillColor: TColor32;
    FSelectionRectBorderColor: TColor32;
    FSelectionRectZoomDeltaColor: array [0..2] of TColor32;
    procedure DoDrawSelectionRect;
    procedure DoDrawSelectionPoly;
    procedure DoDrawCalcLine;
    procedure DoDrawNewPath(AIsPoly: Boolean);
  protected
    procedure DoRedraw; override;
  public
    constructor Create(AParentMap: TImage32; AViewPortState: TMapViewPortState);
    destructor Destroy; override;
    procedure DrawNothing;
    procedure DrawSelectionRect(ASelectedLonLat: TExtendedRect);
    procedure DrawReg(ASelectedLonLatPoly: TExtendedPointArray);
    procedure DrawLineCalc(APathLonLat: TExtendedPointArray; ALenShow: Boolean; AActiveIndex: Integer);
    procedure DrawNewPath(APathLonLat: TExtendedPointArray; AIsPoly: boolean; AActiveIndex: Integer);
  end;

implementation

uses
  Types,
  Graphics,
  SysUtils,
  Ugeofun,
  u_GeoToStr,
  UResStrings,
  u_GlobalState,
  u_WindowLayerBasic;

const
  CRectSize = 1 shl 14;

{ TMapNalLayer }

constructor TMapNalLayer.Create(AParentMap: TImage32; AViewPortState: TMapViewPortState);
var
  i: Integer;
  kz: Integer;
begin
  inherited;
  FLayer.Bitmap.Font.Name := 'Tahoma';
  FPolyPointColor := SetAlpha(clYellow32, 150);
  FPolyActivePointColor := SetAlpha(ClRed32, 255);
  FPolyFirstPointColor := SetAlpha(ClGreen32, 255);
  FPolyLineColor := SetAlpha(ClRed32, 150);
  FPolyFillColor := SetAlpha(ClWhite32, 50);
  FPolyLineWidth := 3;
  FCalcLineColor := SetAlpha(ClRed32, 150);
  FCalcTextColor := clBlack32;
  FCalcTextBGColor := SetAlpha(ClWhite32, 110);
  FCalcPointFillColor := SetAlpha(ClWhite32, 150);
  FCalcPointRectColor := SetAlpha(ClRed32, 150);
  FCalcPointFirstColor := SetAlpha(ClGreen32, 255);
  FCalcPointActiveColor := SetAlpha(ClRed32, 255);
  FSelectionPolyFillColor := SetAlpha(clWhite32, 40);
  FSelectionPolyBorderColor := SetAlpha(clBlue32, 180);
  FSelectionPolyPointFirstColor := SetAlpha(ClGreen32, 255);
  FSelectionPolyPointColor := SetAlpha(ClRed32, 255);
  FSelectionRectFillColor := SetAlpha(clWhite32, 20);
  FSelectionRectBorderColor := SetAlpha(clBlue32, 150);
  for i := 0 to Length(FSelectionRectZoomDeltaColor) - 1 do begin
    kz := 256 shr i;
    FSelectionRectZoomDeltaColor[i] := SetAlpha(RGB(kz - 1, kz - 1, kz - 1), 255);
  end;
end;

destructor TMapNalLayer.Destroy;
begin
  FPath := nil;
  inherited;
end;

procedure TMapNalLayer.DoDrawCalcLine;
var
  i, j, textW: integer;
  k1: TExtendedPoint;
  k2: TExtendedPoint;
  len: real;
  text: string;
  polygon: TPolygon32;
  VBitmapSize: TPoint;
  VPointsOnBitmap: TExtendedPointArray;
  VPointsCount: Integer;
  VLonLat: TExtendedPoint;
begin
  VPointsCount := Length(FPath);
  if VPointsCount > 0 then begin
    SetLength(VPointsOnBitmap, VPointsCount);
    for i := 0 to VPointsCount - 1 do begin
      VLonLat := FPath[i];
      FGeoConvert.CheckLonLatPos(VLonLat);
      VPointsOnBitmap[i] := MapPixel2BitmapPixel(FGeoConvert.LonLat2PixelPosFloat(VLonLat, FZoom));
    end;

    polygon := TPolygon32.Create;
    try
      polygon.Antialiased := true;
      polygon.AntialiasMode := am4times;
      polygon.Closed := false;
      PrepareGR32Polygon(VPointsOnBitmap, polygon);
      with Polygon.Outline do try
         with Grow(Fixed(FPolyLineWidth / 2), 0.5) do try
           FillMode := pfWinding;
           DrawFill(FLayer.Bitmap, FCalcLineColor);
         finally
           free;
         end;
      finally
        free;
      end;
    finally
      polygon.Free;
    end;

    VBitmapSize := GetBitmapSizeInPixel;
    try
      for i := 0 to VPointsCount - 2 do begin
        k2 := VPointsOnBitmap[i + 1];
        if not ((k2.x > 0) and (k2.y > 0)) and ((k2.x < VBitmapSize.X) and (k2.y < VBitmapSize.Y)) then begin
          continue;
        end;
        FLayer.Bitmap.FrameRectS(
          Trunc(k2.x - 3),
          Trunc(k2.y - 3),
          Trunc(k2.X + 3),
          Trunc(k2.Y + 3),
          FCalcPointRectColor
        );
        FLayer.Bitmap.FillRectS(
          Trunc(k2.x - 2),
          Trunc(k2.y - 2),
          Trunc(k2.X + 2),
          Trunc(k2.y + 2),
          FCalcPointFillColor
        );
        if i = VPointsCount - 2 then begin
          len := 0;
          for j := 0 to i do begin
            len := len + FGeoConvert.CalcDist(FPath[j], FPath[j + 1]);
          end;
          text := SAS_STR_Whole + ': ' + DistToStrWithUnits(len, GState.num_format);
          FLayer.Bitmap.Font.Size := 9;
          textW := FLayer.Bitmap.TextWidth(text) + 11;
          FLayer.Bitmap.FillRectS(
            Trunc(k2.x + 12),
            Trunc(k2.y),
            Trunc(k2.X + textW),
            Trunc(k2.y + 15),
            FCalcTextBGColor
          );
          FLayer.Bitmap.RenderText(
            Trunc(k2.X + 15),
            Trunc(k2.y),
            text,
            3,
            FCalcTextColor
          );
        end else begin
          if FLenShow then begin
            text := DistToStrWithUnits(FGeoConvert.CalcDist(FPath[i], FPath[i + 1]), GState.num_format);
            FLayer.Bitmap.Font.Size := 7;
            textW := FLayer.Bitmap.TextWidth(text) + 11;
            FLayer.Bitmap.FillRectS(
              Trunc(k2.x + 5),
              Trunc(k2.y + 5),
              Trunc(k2.X + textW),
              Trunc(k2.y + 16),
              FCalcTextBGColor
            );
            FLayer.Bitmap.RenderText(
              Trunc(k2.X + 8),
              Trunc(k2.y + 5),
              text,
              0,
              FCalcTextColor
            );
          end;
        end;
      end;
      k1 := VPointsOnBitmap[0];
      if ((k1.x > 0) and (k1.y > 0)) and ((k1.x < VBitmapSize.X) and (k1.y < VBitmapSize.Y)) then begin
        k1 := ExtPoint(k1.x - 3, k1.y - 3);
        FLayer.Bitmap.FillRectS(bounds(Round(k1.x), Round(k1.y), 6, 6), FCalcPointFirstColor);
      end;
      k1 := VPointsOnBitmap[FPolyActivePointIndex];
      if ((k1.x > 0) and (k1.y > 0)) and ((k1.x < VBitmapSize.X) and (k1.y < VBitmapSize.Y)) then begin
        k1 := ExtPoint(k1.x - 3, k1.y - 3);
        FLayer.Bitmap.FillRectS(bounds(Round(k1.x), Round(k1.y), 6, 6), FCalcPointActiveColor);
      end;
    finally
      VPointsOnBitmap := nil;
    end;
  end;
end;

procedure TMapNalLayer.DoDrawNewPath(AIsPoly: Boolean);
var
  i: integer;
  k1: TExtendedPoint;
  polygon: TPolygon32;
  VBitmapSize: TPoint;
  VPointsOnBitmap: TExtendedPointArray;
  VPointsCount: Integer;
  VLonLat: TExtendedPoint;
begin
  VPointsCount := Length(FPath);
  if VPointsCount > 0 then begin
    SetLength(VPointsOnBitmap, VPointsCount);
    for i := 0 to VPointsCount - 1 do begin
      VLonLat := FPath[i];
      FGeoConvert.CheckLonLatPos(VLonLat);
      VPointsOnBitmap[i] := MapPixel2BitmapPixel(FGeoConvert.LonLat2PixelPosFloat(VLonLat, FZoom));
    end;
    polygon := TPolygon32.Create;
    try
      polygon.Antialiased := true;
      polygon.AntialiasMode := am4times;
      polygon.Closed := AIsPoly;
      PrepareGR32Polygon(VPointsOnBitmap, polygon);
      if AIsPoly then begin
        Polygon.DrawFill(FLayer.Bitmap, FPolyFillColor);
      end;
      with Polygon.Outline do try
         with Grow(Fixed(FPolyLineWidth / 2), 0.5) do try
           FillMode := pfWinding;
           DrawFill(FLayer.Bitmap, FPolyLineColor);
         finally
           free;
         end;
      finally
        free;
      end;
    finally
      polygon.Free;
    end;

    VBitmapSize := GetBitmapSizeInPixel;
    try
      for i := 1 to VPointsCount - 1 do begin
        k1 := VPointsOnBitmap[i];
        if ((k1.x > 0) and (k1.y > 0)) and ((k1.x < VBitmapSize.X) and (k1.y < VBitmapSize.Y)) then begin
          k1 := ExtPoint(k1.x - 4, k1.y - 4);
          FLayer.Bitmap.FillRectS(bounds(Round(k1.X), Round(k1.y), 8, 8), FPolyPointColor);
        end;
      end;
      k1 := VPointsOnBitmap[0];
      if ((k1.x > 0) and (k1.y > 0)) and ((k1.x < VBitmapSize.X) and (k1.y < VBitmapSize.Y)) then begin
        k1 := ExtPoint(k1.x - 4, k1.y - 4);
        FLayer.Bitmap.FillRectS(bounds(Round(k1.X), Round(k1.y), 8, 8), FPolyFirstPointColor);
      end;
      k1 := VPointsOnBitmap[FPolyActivePointIndex];
      if ((k1.x > 0) and (k1.y > 0)) and ((k1.x < VBitmapSize.X) and (k1.y < VBitmapSize.Y)) then begin
        k1 := ExtPoint(k1.x - 4, k1.y - 4);
        FLayer.Bitmap.FillRectS(bounds(Round(k1.X), Round(k1.y), 8, 8), FPolyActivePointColor);
      end;
    finally
      VPointsOnBitmap := nil;
    end;
  end;
end;

procedure TMapNalLayer.DoDrawSelectionPoly;
var
  i: integer;
  k1: TExtendedPoint;
  Polygon: TPolygon32;
  VBitmapSize: TPoint;
  VPointsOnBitmap: TExtendedPointArray;
  VPointsCount: Integer;
  VLonLat: TExtendedPoint;
begin
  VPointsCount := Length(FPath);
  if VPointsCount > 0 then begin
    SetLength(VPointsOnBitmap, VPointsCount);
    for i := 0 to VPointsCount - 1 do begin
      VLonLat := FPath[i];
      FGeoConvert.CheckLonLatPos(VLonLat);
      VPointsOnBitmap[i] := MapPixel2BitmapPixel(FGeoConvert.LonLat2PixelPosFloat(VLonLat, FZoom));
    end;
    polygon := TPolygon32.Create;
    try
      polygon.Antialiased := true;
      polygon.AntialiasMode := am4times;
      polygon.Closed := true;
      PrepareGR32Polygon(VPointsOnBitmap, polygon);
      Polygon.DrawFill(FLayer.Bitmap, FSelectionPolyFillColor);
      with Polygon.Outline do try
         with Grow(Fixed(FPolyLineWidth / 2), 0.5) do try
           FillMode := pfWinding;
           DrawFill(FLayer.Bitmap, FSelectionPolyBorderColor);
         finally
           free;
         end;
      finally
        free;
      end;
    finally
      polygon.Free;
    end;

    VBitmapSize := GetBitmapSizeInPixel;
    try
      k1 := VPointsOnBitmap[0];
      if ((k1.x > 0) and (k1.y > 0)) and ((k1.x < VBitmapSize.X) and (k1.y < VBitmapSize.Y)) then begin
        k1 := ExtPoint(k1.x - 3, k1.y - 3);
        FLayer.Bitmap.FillRectS(bounds(Round(k1.X), Round(k1.Y), 6, 6), FSelectionPolyPointFirstColor);
      end;
      if VPointsCount > 1 then begin
        k1 := VPointsOnBitmap[VPointsCount - 1];
        if ((k1.x > 0) and (k1.y > 0)) and ((k1.x < VBitmapSize.X) and (k1.y < VBitmapSize.Y)) then begin
          k1 := ExtPoint(k1.x - 3, k1.y - 3);
          FLayer.Bitmap.FillRectS(bounds(Round(k1.X), Round(k1.Y), 6, 6), FSelectionPolyPointColor);
        end;
      end;
    finally
      VPointsOnBitmap := nil;
    end;
  end;
end;

procedure TMapNalLayer.DoDrawSelectionRect;
var
  jj: integer;
  xy1, xy2: TPoint;
  VSelectedPixels: TRect;
  VZoomDelta: Byte;
  VColor: TColor32;
  VSelectedRelative: TExtendedRect;
  VSelectedTiles: TRect;
  VMaxZoomDelta: Integer;
begin
  VSelectedPixels := FGeoConvert.LonLatRect2PixelRect(FSelectedLonLat, FZoom);

  xy1 := MapPixel2BitmapPixel(VSelectedPixels.TopLeft);
  xy1.x := xy1.x;
  xy1.y := xy1.y;
  xy2 := MapPixel2BitmapPixel(VSelectedPixels.BottomRight);
  xy2.x := xy2.x;
  xy2.y := xy2.y;

  FLayer.Bitmap.FillRectS(xy1.x, xy1.y, xy2.x, xy2.y, FSelectionRectFillColor);
  FLayer.Bitmap.FrameRectS(xy1.x, xy1.y, xy2.x, xy2.y, FSelectionRectBorderColor);
  FLayer.Bitmap.FrameRectS(xy1.x - 1, xy1.y - 1, xy2.x + 1, xy2.y + 1, FSelectionRectBorderColor);

  VSelectedRelative := FGeoConvert.PixelRect2RelativeRect(VSelectedPixels, FZoom);

  jj := FZoom;
  VZoomDelta := 0;
  VMaxZoomDelta := Length(FSelectionRectZoomDeltaColor) - 1;
  while (VZoomDelta <= VMaxZoomDelta) and (jj < 24) do begin
    VSelectedTiles := FGeoConvert.RelativeRect2TileRect(VSelectedRelative, jj);
    VSelectedPixels := FGeoConvert.RelativeRect2PixelRect(
      FGeoConvert.TileRect2RelativeRect(VSelectedTiles, jj), FZoom
    );

    xy1 := MapPixel2BitmapPixel(VSelectedPixels.TopLeft);
    xy2 := MapPixel2BitmapPixel(VSelectedPixels.BottomRight);

    VColor := FSelectionRectZoomDeltaColor[VZoomDelta];

    FLayer.Bitmap.FrameRectS(
      xy1.X - (VZoomDelta + 1), xy1.Y - (VZoomDelta + 1),
      xy2.X + (VZoomDelta + 1), xy2.Y + (VZoomDelta + 1),
      VColor
    );

    FLayer.Bitmap.Font.Size := 11;
    FLayer.Bitmap.RenderText(
      xy2.x - ((xy2.x - xy1.x) div 2) - 42 + VZoomDelta * 26,
      xy2.y - ((xy2.y - xy1.y) div 2) - 6,
      'x' + inttostr(jj + 1), 3, VColor
    );
    Inc(jj);
    Inc(VZoomDelta);
  end;
end;

procedure TMapNalLayer.DoRedraw;
begin
  inherited;
  FLayer.Bitmap.Clear(clBlack);
  case FDrawType of
    mndtNothing:;
    mndtSelectRect: DoDrawSelectionRect;
    mndtSelectPoly: DoDrawSelectionPoly;
    mndtCalcLen: DoDrawCalcLine;
    mndtNewPath: DoDrawNewPath(False);
    mndtNewPoly: DoDrawNewPath(True);
  end;
end;

procedure TMapNalLayer.DrawLineCalc(APathLonLat: TExtendedPointArray; ALenShow: Boolean; AActiveIndex: Integer);
begin

  FDrawType := mndtCalcLen;
  FPath := Copy(APathLonLat);

  FPolyActivePointIndex := AActiveIndex;
  FLenShow := ALenShow;
  Redraw;
end;

procedure TMapNalLayer.DrawNewPath(APathLonLat: TExtendedPointArray;
  AIsPoly: boolean; AActiveIndex: Integer);
begin
  if AIsPoly then begin
    FDrawType := mndtNewPoly;
  end else begin
    FDrawType := mndtNewPath;
  end;
  FPath := Copy(APathLonLat);
  FPolyActivePointIndex := AActiveIndex;
  if (FPolyActivePointIndex < 0) or (FPolyActivePointIndex >= length(FPath)) then begin
    FPolyActivePointIndex := length(FPath) - 1;
  end;
  Redraw;
end;

procedure TMapNalLayer.DrawNothing;
begin
  FDrawType := mndtNothing;
  FPath := nil;
  Redraw;
end;

procedure TMapNalLayer.DrawReg(ASelectedLonLatPoly: TExtendedPointArray);
begin
  FDrawType := mndtSelectPoly;
  FPath := Copy(ASelectedLonLatPoly);
  Redraw;
end;

procedure TMapNalLayer.DrawSelectionRect(ASelectedLonLat: TExtendedRect);
begin
  FDrawType := mndtSelectRect;
  FPath := nil;
  FSelectedLonLat := ASelectedLonLat;
  Redraw;
end;

end.
