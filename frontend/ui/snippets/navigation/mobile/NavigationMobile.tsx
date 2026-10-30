import { Box, Flex, VStack } from '@chakra-ui/react';
import React from 'react';

import useNavItems, { isGroupItem } from 'lib/hooks/useNavItems';
import useIsAuth from 'ui/snippets/auth/useIsAuth';

import NavigationPromoBanner from '../promoBanner/NavigationPromoBanner';
import NavLink from '../vertical/NavLink';
import NavLinkRewards from '../vertical/NavLinkRewards';
import NavSection from '../vertical/NavSection';

interface Props {
  onNavLinkClick?: () => void;
  isMarketplaceAppPage?: boolean;
}

// RoxChain: menu groups are listed in place (heading + links), the same as the desktop sidebar, without a second sliding panel
const NavigationMobile = ({ onNavLinkClick, isMarketplaceAppPage }: Props) => {
  const { mainNavItems, accountNavItems } = useNavItems();

  const isAuth = useIsAuth();

  const isCollapsed = isMarketplaceAppPage ? false : undefined;

  return (
    <Flex position="relative" flexDirection="column" flexGrow={ 1 }>
      <Box as="nav" mt={ 6 }>
        <VStack
          w="100%"
          as="ul"
          gap="1"
          alignItems="flex-start"
        >
          { mainNavItems.map((item) => {
            if (isGroupItem(item)) {
              return <NavSection key={ item.text } item={ item } onClick={ onNavLinkClick } isCollapsed={ isCollapsed }/>;
            } else {
              return <NavLink key={ item.text } item={ item } onClick={ onNavLinkClick } isCollapsed={ isCollapsed }/>;
            }
          }) }
        </VStack>
      </Box>
      { isAuth && (
        <Box
          as="nav"
          mt={ 3 }
          pt={ 3 }
          borderTopWidth="1px"
          borderColor="border.divider"
        >
          <VStack as="ul" gap="1" alignItems="flex-start">
            <NavLinkRewards onClick={ onNavLinkClick } isCollapsed={ isCollapsed }/>
            { accountNavItems.map((item) => <NavLink key={ item.text } item={ item } onClick={ onNavLinkClick } isCollapsed={ isCollapsed }/>) }
          </VStack>
        </Box>
      ) }
      <NavigationPromoBanner isCollapsed={ isCollapsed }/>
    </Flex>
  );
};

export default NavigationMobile;
