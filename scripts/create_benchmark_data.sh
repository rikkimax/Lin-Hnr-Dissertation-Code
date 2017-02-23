pushd ..

# cleanup
rm -rf benchmarks
mkdir benchmarks

# ok lets build the damn program!

dub build :data --build=release
dub build :graph --build=release

# and now the data creation

./scripts/create.sh
./scripts/run.sh
./graph

popd
