#import "../utils.typ": todo, silentheading, flex-caption

= Podsumowanie i wnioski
W ramach projektu zapoznaliśmy się i zaimplementowaliśmy operację splotu na obrazie z wykorzystaniem filtra do wykrywania krawędzi, bazując na filtrze Sobela.

Po stworzeniu implementacji sekwencyjnej zrównolegliliśmy działanie kodu na 3 rózne sposoby, poznając przy okazji biblioteki SYCL, OpenMP i MPI. Przy każdej metodzie zaobserwowaliśmy znaczący wzrost wydajności jaki ten algorytm wykazuje przy zrównolegleniu. 

#todo[Dodać jakieś szczegóły jak będziemy mieli pełne benchmarki]

Projekt dał nam więc okazję do zobaczenia jak znaczący stosunek zysku wydajności do włożonego wysiłku może nieraz zapewnić zrównoleglenie z użyciem współczesnych bibliotek i standardów, co najpewniej będziemy próbować aplikować w naszych przyszłych projektach programistycznych.