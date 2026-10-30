import { Box, chakra } from '@chakra-ui/react';
import React from 'react';

interface Props {
  className?: string;
}

const AdminSupportText = ({ className }: Props) => {
  return (
    <Box className={ className }>
      <span>Need help? Contact the RoxChain team for assistance.</span>
    </Box>
  );
};

export default chakra(AdminSupportText);
