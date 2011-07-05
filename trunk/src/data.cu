#include "../include/data.cuh"
/* 
 * Author: Alex Krizhevsky (akrizhevsky@gmail.com)
 * June 2011
 */
using namespace std;

DataProvider::DataProvider(int minibatchSize) : 
    _minibatchSize(minibatchSize), _hData(NULL) {

}

GPUData& DataProvider::operator[](int idx) {
    return getMinibatch(idx);
}


void DataProvider::setData(CPUData& hData) {
    assert(&hData != NULL);
    assert(hData.getSize() > 0);
    assert(hData[0].getLeadingDim() % _minibatchSize == 0);
    assert(hData.getNumCases() <= hData[0].getLeadingDim());
    for (int i = 1; i < hData.getSize(); i++) {
        assert(hData[i-1].getLeadingDim() == hData[i].getLeadingDim());
    }
    if (_hData != NULL) { // Delete old CPU matrices
        delete _hData;
    }

    _hData = &hData;
    _dataSize = 0;
    for (int i = 0; i < hData.getSize(); i++) {
        _dataSize += hData[i].getNumDataBytes();
    }
    _dataSize /= 1024 * 1024;
    if (_dataSize < MAX_DATA_ON_GPU) {
        for (int i = 0; i < hData.getSize(); i++) {
            if (i >= _data.size()) {
                _data.push_back(new NVMatrix());
            }
            _data[i]->copyFromHost(hData[i], true);
        }
    }
}

GPUData& DataProvider::getMinibatch(int idx) {
    assert(_hData->getNumCases() > 0);
    assert(idx >= 0 && idx < getNumMinibatches());
    
    NVMatrixV& miniData = *new NVMatrixV();
    
    for (int i = 0; i < _hData->getData().size(); i++) {
        miniData.push_back(new NVMatrix());
        if (_dataSize < MAX_DATA_ON_GPU) {
            if (_data[i]->isTrans()) {
                _data[i]->sliceRows(idx * _minibatchSize, (idx + 1) * _minibatchSize, *miniData[i]);
            } else {
                _data[i]->sliceCols(idx * _minibatchSize, (idx + 1) * _minibatchSize, *miniData[i]);
            }
        } else {
            Matrix tmp;
            if ((*_hData)[i].isTrans()) {
                (*_hData)[i].sliceRows(idx * _minibatchSize, (idx + 1) * _minibatchSize, tmp);
            } else {
                (*_hData)[i].sliceCols(idx * _minibatchSize, (idx + 1) * _minibatchSize, tmp);
            }
            miniData.back()->copyFromHost(tmp, true);
        }
    }

    return *new GPUData(miniData, getNumCasesInMinibatch(idx));
}

int DataProvider::getNumMinibatches() {
    assert(_hData->getNumCases() > 0);
    return (*_hData)[0].getLeadingDim() / _minibatchSize;
}

int DataProvider::getMinibatchSize() {
    return _minibatchSize;
}

int DataProvider::getNumCases() {
    assert(_hData->getNumCases() > 0);
    return _hData->getNumCases();
}

int DataProvider::getNumCasesInMinibatch(int idx) {
    assert(_hData->getNumCases() > 0);
    assert(idx >= 0 && idx < getNumMinibatches());
    return min(_minibatchSize, max(0, _hData->getNumCases() - idx * _minibatchSize));
}