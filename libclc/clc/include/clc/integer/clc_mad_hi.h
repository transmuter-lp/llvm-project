//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef __CLC_INTEGER_CLC_MAD_HI_H__
#define __CLC_INTEGER_CLC_MAD_HI_H__

#include <clc/integer/clc_mul_hi.h>

#define __clc_mad_hi(a, b, c) (__clc_mul_hi((a), (b)) + (c))

#endif // __CLC_INTEGER_CLC_MAD_HI_H__
