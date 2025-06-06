//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

// <queue>

// priority_queue& operator=(const priority_queue&) = default;

#include <queue>
#include <cassert>
#include <functional>

#include "test_macros.h"

template <class C>
TEST_CONSTEXPR_CXX26 C make(int n) {
  C c;
  for (int i = 0; i < n; ++i)
    c.push_back(i);
  return c;
}

TEST_CONSTEXPR_CXX26 bool test() {
  std::vector<int> v = make<std::vector<int> >(5);
  std::priority_queue<int, std::vector<int>, std::greater<int> > qo(std::greater<int>(), v);
  std::priority_queue<int, std::vector<int>, std::greater<int> > q;
  q = qo;
  assert(q.size() == 5);
  assert(q.top() == 0);

  return true;
}

int main(int, char**) {
  assert(test());
#if TEST_STD_VER >= 26
  static_assert(test());
#endif

  return 0;
}
