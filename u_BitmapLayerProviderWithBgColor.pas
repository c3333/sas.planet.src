unit u_BitmapLayerProviderWithBGColor;

interface

uses
  GR32,
  i_OperationNotifier,
  i_Bitmap32Static,
  i_LocalCoordConverter,
  i_BitmapLayerProvider;

type
  TBitmapLayerProviderWithBGColor = class(TInterfacedObject, IBitmapLayerProvider)
  private
    FSourceProvider: IBitmapLayerProvider;
    FBackGroundColor: TColor32;
  private
    function GetBitmapRect(
      AOperationID: Integer;
      ACancelNotifier: IOperationNotifier;
      ALocalConverter: ILocalCoordConverter
    ): IBitmap32Static;
  public
    constructor Create(
      ABackGroundColor: TColor32;
      ASourceProvider: IBitmapLayerProvider
    );
  end;

implementation

uses
  GR32_Resamplers;

{ TBitmapLayerProviderWithBGColor }

constructor TBitmapLayerProviderWithBGColor.Create(ABackGroundColor: TColor32;
  ASourceProvider: IBitmapLayerProvider);
begin
  FSourceProvider := ASourceProvider;
  FBackGroundColor := ABackGroundColor;
  Assert(FSourceProvider <> nil);
end;

function TBitmapLayerProviderWithBGColor.GetBitmapRect(
  AOperationID: Integer;
  ACancelNotifier: IOperationNotifier;
  ALocalConverter: ILocalCoordConverter
): IBitmap32Static;
var
  VTileSize: TPoint;
  VTargetBmp: TCustomBitmap32;
begin
  Result :=
    FSourceProvider.GetBitmapRect(
      AOperationID,
      ACancelNotifier,
      ALocalConverter
    );
  if Result <> nil then begin
    VTargetBmp := TCustomBitmap32.Create;
    try
      VTileSize := ALocalConverter.GetLocalRectSize;
      VTargetBmp.SetSize(VTileSize.X, VTileSize.Y);
      VTargetBmp.Clear(FBackGroundColor);
      BlockTransfer(
        VTargetBmp,
        0,
        0,
        VTargetBmp.ClipRect,
        Result.Bitmap,
        Result.Bitmap.BoundsRect,
        dmBlend
      );
    finally
      VTargetBmp.Free;
    end;
  end;
end;

end.
