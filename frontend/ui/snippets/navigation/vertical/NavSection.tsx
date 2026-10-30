import { Box, Text, VStack } from '@chakra-ui/react';
import React from 'react';

import type { NavGroupItem } from 'types/client/navigation';

import NavLink from './NavLink';

// RoxChain: a menu group is shown as a heading with all of its links listed under it, instead of a fly-out sub-menu;
// a collapsed sidebar shows a divider in place of the heading
type Props = {
  item: NavGroupItem;
  isCollapsed?: boolean;
  onClick?: () => void;
};

const NavSection = ({ item, isCollapsed, onClick }: Props) => {
  const isExpanded = isCollapsed === false;
  const links = item.subItems.flat();

  return (
    <Box as="li" listStyleType="none" w="100%" _notFirst={{ mt: 4 }}>
      <Text
        display={{ base: 'block', lg: isExpanded ? 'block' : 'none', xl: isCollapsed ? 'none' : 'block' }}
        px={ 2 }
        mb={ 1 }
        textStyle="xs"
        fontWeight={ 600 }
        color="text.secondary"
        whiteSpace="nowrap"
      >
        { item.text }
      </Text>
      <Box
        display={{ base: 'none', lg: isExpanded ? 'none' : 'block', xl: isCollapsed ? 'block' : 'none' }}
        borderTopWidth="1px"
        borderColor="border.divider"
        mx={ 2 }
        mb={ 2 }
      />
      <VStack as="ul" gap="1" alignItems="flex-start">
        { links.map((link) => <NavLink key={ link.text } item={ link } isCollapsed={ isCollapsed } onClick={ onClick }/>) }
      </VStack>
    </Box>
  );
};

export default React.memo(NavSection);
