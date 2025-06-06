// RUN: %clang_cc1 %s -fopenacc -verify

typedef struct IsComplete {
  struct S { int A; } CompositeMember;
  int ScalarMember;
  float ArrayMember[5];
  void *PointerMember;
} Complete;
void uses(int IntParam, short *PointerParam, float ArrayParam[5], Complete CompositeParam) {
  int LocalInt;
  short *LocalPointer;
  float LocalArray[5];
  Complete LocalComposite;
  // Check Appertainment:
#pragma acc parallel copy(LocalInt)
  while(1);
#pragma acc serial copy(LocalInt)
  while(1);
#pragma acc kernels copy(LocalInt)
  while(1);

  // expected-warning@+1{{OpenACC clause name 'pcopy' is a deprecated clause name and is now an alias for 'copy'}}
#pragma acc parallel pcopy(LocalInt)
  while(1);

  // expected-warning@+1{{OpenACC clause name 'present_or_copy' is a deprecated clause name and is now an alias for 'copy'}}
#pragma acc parallel present_or_copy(LocalInt)
  while(1);

  // Valid cases:
#pragma acc parallel copy(LocalInt, LocalPointer, LocalArray)
  while(1);
#pragma acc parallel copy(LocalArray[2:1])
  while(1);

#pragma acc parallel copy(LocalComposite.ScalarMember, LocalComposite.ScalarMember)
  while(1);

  // expected-error@+1{{OpenACC variable is not a valid variable name, sub-array, array element, member of a composite variable, or composite variable member}}
#pragma acc parallel copy(1 + IntParam)
  while(1);

  // expected-error@+1{{OpenACC variable is not a valid variable name, sub-array, array element, member of a composite variable, or composite variable member}}
#pragma acc parallel copy(+IntParam)
  while(1);

  // expected-error@+1{{OpenACC sub-array length is unspecified and cannot be inferred because the subscripted value is not an array}}
#pragma acc parallel copy(PointerParam[2:])
  while(1);

  // expected-error@+1{{OpenACC sub-array specified range [2:5] would be out of the range of the subscripted array size of 5}}
#pragma acc parallel copy(ArrayParam[2:5])
  while(1);

  // expected-error@+2{{OpenACC sub-array specified range [2:5] would be out of the range of the subscripted array size of 5}}
  // expected-error@+1{{OpenACC variable is not a valid variable name, sub-array, array element, member of a composite variable, or composite variable member}}
#pragma acc parallel copy((float*)ArrayParam[2:5])
  while(1);
  // expected-error@+1{{OpenACC variable is not a valid variable name, sub-array, array element, member of a composite variable, or composite variable member}}
#pragma acc parallel copy((float)ArrayParam[2])
  while(1);

  // expected-error@+1{{OpenACC 'copy' clause is not valid on 'loop' directive}}
#pragma acc loop copy(LocalInt)
  for(int i = 5; i < 10;++i);
  // expected-error@+1{{OpenACC 'pcopy' clause is not valid on 'loop' directive}}
#pragma acc loop pcopy(LocalInt)
  for(int i = 5; i < 10;++i);
  // expected-error@+1{{OpenACC 'present_or_copy' clause is not valid on 'loop' directive}}
#pragma acc loop present_or_copy(LocalInt)
  for(int i = 5; i < 10;++i);

  short *ArrayOfPtrs[5];
#pragma acc parallel copy(ArrayOfPtrs[1:1])
  ;
  // expected-error@+1{{OpenACC sub-array length is unspecified and cannot be inferred because the subscripted value is not an array}}
#pragma acc parallel copy(ArrayOfPtrs[1:1][1])
  ;
  // expected-error@+1{{OpenACC sub-array length is unspecified and cannot be inferred because the subscripted value is not an array}}
#pragma acc parallel copy(ArrayOfPtrs[1:1][1:])
  ;
#pragma acc parallel copy(ArrayOfPtrs[1:1][1:2])
  ;

}
void ModList() {
  int V1;
  // expected-error@+2{{OpenACC 'readonly' modifier not valid on 'copy' clause}}
  // expected-error@+1{{OpenACC 'zero' modifier not valid on 'copy' clause}}
#pragma acc parallel copy(always, alwaysin, alwaysout, zero, readonly: V1)
  for(int i = 5; i < 10;++i);
  // expected-error@+1{{OpenACC 'readonly' modifier not valid on 'copy' clause}}
#pragma acc serial copy(readonly: V1)
  for(int i = 5; i < 10;++i);
  // expected-error@+1{{OpenACC 'zero' modifier not valid on 'copy' clause}}
#pragma acc kernels copy(zero: V1)
  for(int i = 5; i < 10;++i);
#pragma acc parallel copy(capture:V1)
  for(int i = 5; i < 10;++i);
#pragma acc parallel copy(always, alwaysin, alwaysout, capture: V1)
  for(int i = 5; i < 10;++i);
}
