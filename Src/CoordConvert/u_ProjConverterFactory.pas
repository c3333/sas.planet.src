{******************************************************************************}
{* SAS.Planet (SAS.�������)                                                   *}
{* Copyright (C) 2007-2014, SAS.Planet development team.                      *}
{* This program is free software: you can redistribute it and/or modify       *}
{* it under the terms of the GNU General Public License as published by       *}
{* the Free Software Foundation, either version 3 of the License, or          *}
{* (at your option) any later version.                                        *}
{*                                                                            *}
{* This program is distributed in the hope that it will be useful,            *}
{* but WITHOUT ANY WARRANTY; without even the implied warranty of             *}
{* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              *}
{* GNU General Public License for more details.                               *}
{*                                                                            *}
{* You should have received a copy of the GNU General Public License          *}
{* along with this program.  If not, see <http://www.gnu.org/licenses/>.      *}
{*                                                                            *}
{* http://sasgis.org                                                          *}
{* info@sasgis.org                                                            *}
{******************************************************************************}

unit u_ProjConverterFactory;

interface

uses
  Windows,
  SysUtils,
  i_ProjConverter,
  u_BaseInterfacedObject;

type
  TProjConverterFactory = class(TBaseInterfacedObject, IProjConverterFactory)
  private
    FProj4Status: Integer; // 0 - not loaded; 1 - ok; 2 - error
  private
    function _GetArgsByEpsg(const AEPSG: Integer): AnsiString;
    function _GetByInitString(const AArgs: AnsiString): IProjConverter;
  private
    { IProjConverterFactory }
    function GetByEPSG(const AEPSG: Integer): IProjConverter;
    function GetByInitString(const AArgs: AnsiString): IProjConverter;
  public
    constructor Create;
  end;

implementation

uses
  Proj4,
  ALString,
  u_ProjConverterByDll;

const
  cProj4NotLoaded = 0;
  cProj4LoadedOK = 1;
  cProj4LoadedError = 2;

{ TProjConverterFactory }

constructor TProjConverterFactory.Create;
begin
  inherited Create;
  FProj4Status := cProj4NotLoaded;
end;

function TProjConverterFactory._GetArgsByEpsg(const AEPSG: Integer): AnsiString;
var
  I: Integer;
begin
  Result := '';
  // known EPSGs
  if AEPSG = 53004 then begin
    // Sphere Mercator ESRI:53004
    Result := '+proj=merc +lon_0=0 +k=1 +x_0=0 +y_0=0 +a=6371000 +b=6371000 +units=m +no_defs';
  end else if AEPSG = 3785 then begin
    // Popular Visualisation CRS / Mercator
    Result := '+proj=merc +lon_0=0 +k=1 +x_0=0 +y_0=0 +a=6378137 +b=6378137 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs';
  end else if AEPSG = 3395 then begin
    // WGS 84 / World Mercator
    Result := '+proj=merc +lon_0=0 +k=1 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs';
  end else if AEPSG = 4269 then begin
    // NAD83
    Result := '+proj=longlat +ellps=GRS80 +datum=NAD83 +no_defs';
  end else if AEPSG = 4326 then begin
    // WGS 84
    Result := wgs84;
  end else if (AEPSG >= 2463) and (AEPSG <= 2491) then begin
    // 2463-2491 = Pulkovo 1995 / Gauss-Kruger CM
    I := 21 + (AEPSG - 2463) * 6;
    if I > 180 then begin
      I := I - 360;
    end;
    Result := '+proj=tmerc +lat_0=0 +lon_0=' + ALIntToStr(I) + ' +k=1 +x_0=500000 +y_0=0 +ellps=krass +units=m +no_defs';
  end else if (AEPSG >= 2492) and (AEPSG <= 2522) then begin
    // 2492-2522 = Pulkovo 1942 / Gauss-Kruger CM
    I := 9 + (AEPSG - 2492) * 6;
    if I > 180 then begin
      I := I - 360;
    end;
    Result := '+proj=tmerc +lat_0=0 +lon_0=' + ALIntToStr(I) + ' +k=1 +x_0=500000 +y_0=0 +ellps=krass +units=m +no_defs';
  end else if (AEPSG >= 32601) and (AEPSG <= 32660) then begin
    // 32601-32660 = WGS 84 / UTM zone N
    Result := '+proj=utm +zone=' + ALIntToStr(AEPSG - 32600) + ' +ellps=WGS84 +datum=WGS84 +units=m +no_defs';
  end;
end;

function TProjConverterFactory._GetByInitString(
  const AArgs: AnsiString
): IProjConverter;
var
  VProj4Status: Integer;
begin
  Result := nil;
  if AArgs <> '' then begin

    VProj4Status := InterlockedCompareExchange(FProj4Status, 0, 0);

    if VProj4Status = cProj4NotLoaded then begin
      try
        if init_proj4_dll(proj4_dll, True) then begin
          VProj4Status := cProj4LoadedOK;
        end else begin
          VProj4Status := cProj4LoadedError;
        end;
        InterlockedExchange(FProj4Status, VProj4Status);
      except
        InterlockedExchange(FProj4Status, cProj4LoadedError);
        raise;
      end;
    end;

    if VProj4Status = cProj4LoadedOK then begin
      Result := TProjConverterByDll.Create(AArgs);
    end;
  end;
end;

function TProjConverterFactory.GetByEPSG(const AEPSG: Integer): IProjConverter;
var
  VArgs: AnsiString;
begin
  VArgs := _GetArgsByEpsg(AEPSG);
  Result := _GetByInitString(VArgs);
end;

function TProjConverterFactory.GetByInitString(
  const AArgs: AnsiString
): IProjConverter;
const
  cEPSG: AnsiString = 'EPSG:';
var
  VEPSG: Integer;
  VArgs: AnsiString;
begin
  VArgs := AArgs;
  if ALSameText(ALCopyStr(AArgs, 1, Length(cEPSG)), cEPSG) then begin
    if ALTryStrToInt(ALCopyStr(AArgs, Length(cEPSG) + 1, Length(AArgs)), VEPSG) then begin
      VArgs := _GetArgsByEpsg(VEPSG);
    end;
  end;
  Result := _GetByInitString(VArgs);
end;

end.
