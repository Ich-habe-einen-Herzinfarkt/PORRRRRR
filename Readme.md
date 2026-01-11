# Build & Run

## CLion (Testowana opcja)
Tej metody użyto w trakcie tworzenia kodu - kompilator MinGW z Ninja
```sh
"C:\Program Files\JetBrains\CLion 2023.2.2\bin\cmake\win\x64\bin\cmake.exe" --build C:\Users\Mateusz\CLionProjects\PORRRRRR\cmake-build-debug --target PORRRRRR -j 30
```

## Windows (MinGW)
```sh
mkdir build
cd build
cmake -G "MinGW Makefiles" ..
mingw32-make
.\PORRRRRR.exe
```


## Linux
```sh
mkdir build
cd build
cmake ..
cmake --build .
./PORRRRRR
```


## Uruchamianie OpenMP
Wystarczy podać ilość wątków jako argument do zbudowanego pliku .exe
```sh
./PORRRRRR.exe [liczba_wątków]
```

