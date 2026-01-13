#import "../utils.typ": todo, silentheading, flex-caption

= Podsumowanie i wnioski
W ramach projektu zapoznaliśmy się i zaimplementowaliśmy operację splotu na obrazie z wykorzystaniem filtra do wykrywania krawędzi, bazując na filtrze Sobela.

Po stworzeniu implementacji sekwencyjnej zrównolegliliśmy działanie kodu na 3 rózne sposoby, poznając przy okazji biblioteki SYCL, OpenMP i MPI. Przy każdej metodzie zaobserwowaliśmy znaczący wzrost wydajności jaki ten algorytm wykazuje przy zrównolegleniu. 

Jednocześnie jednak mogliśmy zaobserwować, że nieraz znaczące zyski można uzyskać optymalizując sam algorytm - trochę pracy nad wersją sekwencyjną pozwoliło uzyskać na jednym rdzeniu wydajność lepszą niż naiwny algorytm był w stanie osiągnąć na 12.

Projekt dał nam więc okazję do zobaczenia jak znaczący stosunek zysku wydajności do włożonego wysiłku może nieraz zapewnić zrównoleglenie z użyciem współczesnych bibliotek i standardów, co najpewniej będziemy próbować aplikować w naszych przyszłych projektach programistycznych.