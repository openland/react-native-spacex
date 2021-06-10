import { NativeModules } from 'react-native';

type SpacexType = {
  multiply(a: number, b: number): Promise<number>;
};

const { Spacex } = NativeModules;

export default Spacex as SpacexType;
