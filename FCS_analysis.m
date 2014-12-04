function varargout=FCS_computecorrelation (varargin)

%
% Scanning FCS:
%[FCSintervalos, Gintervalos, FCSmean, Gmean, tData, imgROI, imgALIN, tPromedioLS]=...
%    FCS_analysis (photonArrivalTimes, imgDecode, numIntervalos, binFreq, tauLagMax, numSecciones, numPuntosSeccion, base, numSubIntervalosError, tipoCorrelacion...
%    imgBin, lineSync, indLinesLS, indMaxCadaLinea, sigma2_5);
%
%
% Point FCS
%[FCSintervalos, Gintervalos, FCSmean, Gmean]=...
%   FCS_analysis (photonArrivalTimes, numIntervalos, binFreq, tauLagMax, numSecciones, numPuntosSeccion, base, numSubIntervalosError, tipoCorrelacion)
%
%
%   FCSintervalos es FCSData de cada intervalo (los datos de FCS en bins temporales de tama�o deltaT=1/binFreq)
%   Gintervalos es la curva experimental de correlaci�n de cada intervalo con su tiempo, su traza y su error en la tercera columna
%   FCSmean es el promedio de todas las trazas
%   Gmean es el promedio de todas las curvas de correlaci�n
%
%   photonArrivalTimes es la matriz de tiempos de llegada (arrivalTimes) de B&H
%   binFreq es la frecuencia del binning, en Hz
%   numIntervalos es el n�mero de numIntervalos en los que dividimos la traza temporal. Generalmente son de 10s cada uno
%Par�metros del algoritmo multitau
%   numSecciones es el n�mero de secciones en las que divide la curva de correlaci�n
%   base define la resoluci�n temporal de cada secci�n
%   numPuntosSeccion es el n�mero de puntos en los que se calcula la curva de
%   autocorrelaci�n (en cada secci�n). numPuntosSeccion define, por tanto, la precisi�n del ajuste
%   tauLagMax es el �ltimo punto temporal (tiempo m�ximo) para el que se calcula la correlaci�n (con todos los fotones adquiridos, incluyendo los de momentos posteriores a tauLagMax)
%Par�metros del c�lculo de la incertidumbre
%   numSubIntervalosError es el n�mero de subintercalos para los que calcula la correlaci�n y que utiliza para obtener la incertidumbre (error est�ndar) de cada punto de la curva de correlaci�n
%
%   tipoCorrelacion puede ser auto, cross o todas 
%
%   TAC range y TACgain dependen del reloj SYNC (ya o hay que introducirlos como argumentos)
%
%
%   En el caso de scanning FCS hay que llamar antes a FCS_align, que hace
%   el ROI y despu�s la alineaci�n
%
% Basado en FCS_analisis_BH
% ULS Sep2014
% jri 25Nov14


photonArrivalTimes=varargin{1};
numIntervalos=varargin{2};
binFreq=varargin{3};
tauLagMax=varargin{4};
numSecciones=varargin{5};
numPuntosSeccion=varargin{6};
base=varargin{7};
numSubIntervalosError=varargin{8};
tipoCorrelacion=varargin{9};

% Es esto necesario? No parece que lo est� usando
isOpen=matlabpool ('size')>0;
if not(isOpen) %Inicializa matlabpool con el m�ximo numero de cores
    numWorkers=feature('NumCores'); %N�mero de workers activos. 
    if numWorkers>=8
        numWorkers=8; %Para Matlab 2010b, 8 cores m�ximo.
    end
    disp (['Inicializando matlabpool con ' num2str(numWorkers) ' cores'])
matlabpool ('open', numWorkers) 
end


isScanning = logical(size(photonArrivalTimes,2)-3); %isScanning es true si se trata de scanning FCS; sino, false
if isScanning
    imgBin=varargin{10};
    lineSync=varargin{11};
    indLinesLS=varargin{12};
    indMaxCadaLinea=varargin{13};
    sigma2_5=varargin{14};
        
    macroTimeCol=4;
    microTimeCol=5;
    channelsCol=6;
    
else
    macroTimeCol=1;
    microTimeCol=2;
    channelsCol=3;
end

numCanales=numel(unique(photonArrivalTimes(:, channelsCol)));
deltaTBin=1/binFreq;

if isScanning
    multiploLineas=2; %Es el binning de 2 l�neas; equivalente a binFreq. Tiene que salir de binFreq
    [FCSData, deltaTBin]=FCS_binning_FIFO_lines(imgBin, lineSync, indLinesLS, indMaxCadaLinea, sigma2_5, multiploLineas); % Binning temporal de imgBIN, en m�ltiplos de l�nea de la imagen
    
else %isSCanningFCS==0 -  Esto es FCS puntual
    FCSDataALINcorregido=0;
    imgDecode=0;
    imgROI=0;
    imgALIN=0;
    tPromedioLS=0;
    switch numCanales
        case 1
            t0=photonArrivalTimes(1, macroTimeCol)+photonArrivalTimes(1, microTimeCol); %pixel de referencia para binning (1er photon)
        case 2 
            t0channels=zeros(numCanales,1);
            for channel=1:numCanales
                indPrimerPhotonCanal=find(photonArrivalTimes(:, channelsCol)==channel-1,1,'first');
                t0channels(channel)=photonArrivalTimes(indPrimerPhotonCanal, macroTimeCol)+photonArrivalTimes(indPrimerPhotonCanal, microTimeCol);
            end
            t0=min(t0channels);
    end
    FCSData=FCS_binning_FIFO_pixel1(photonArrivalTimes, binFreq, t0); %Binning temporal de FCSDataALINcorregido con los datos del Macro+micro times
end %end if isSCanningFCS

FCSintervalos= FCS_troceador(FCSData, numIntervalos);
Gintervalos= FCS_matriz (FCSintervalos, numSubIntervalosError, deltaTBin, numSecciones, numPuntosSeccion, base, tauLagMax, tipoCorrelacion);
[FCSmean Gmean]=FCS_promedio(Gintervalos, FCSintervalos, 1:numIntervalos, deltaTBin, tipoCorrelacion);
tData=(1:size(FCSintervalos, 1))/binFreq;

if isScanning
    varargout={FCSintervalos, Gintervalos, FCSmean, Gmean, tData, imgROI, imgALIN};
else
    varargout={FCSintervalos, Gintervalos, FCSmean, Gmean, tData};
end

