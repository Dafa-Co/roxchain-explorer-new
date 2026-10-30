import { chakra } from '@chakra-ui/react';
import React from 'react';

import config from 'configs/app';

interface Props {
  className?: string;
}

// RoxChain: a solid, high-contrast pill instead of the thin outlined label image, so the testnet is easy to spot
const TestnetBadge = ({ className }: Props) => {
  if (!config.chain.isTestnet) {
    return null;
  }

  return (
    <chakra.span
      className={ className }
      display="inline-flex"
      alignItems="center"
      h="18px"
      px={ 2 }
      borderRadius="full"
      bgColor="orange.400"
      color="gray.900"
      fontSize="10px"
      fontWeight={ 700 }
      letterSpacing="0.08em"
      lineHeight="18px"
      textTransform="uppercase"
      whiteSpace="nowrap"
    >
      { config.chain.testnetLabel }
    </chakra.span>
  );
};

export default React.memo(chakra(TestnetBadge));
