# Build & Run

## Windows (MinGW) && (hopefully) Linux
Remember to put input image in the same directory in which you run the code or change input_path variable in ```main.cpp```.
```sh
mkdir build
cd build
cmake ..
cmake --build .
mpiexec -n [liczba_watkow] .\PORRRRRR
```

